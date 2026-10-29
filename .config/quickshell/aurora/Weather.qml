pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Weather for the calendar popup: open-meteo (no API key) every 30 min, cached in ~/.cache/aurora/weather.json so a
// restart shows the last one at once. Place = Settings.weatherLoc: "" = by IP (ipinfo.io), "lat,lon", or a place name
// (open-meteo geocoding). Offline / overloaded -> retry in 2 min. QML timers stand still during suspend, so the popup
// calls poke() on open to catch up.
// After glyph-rice (github.com/Nebelung-cloud/glyph-rice, GPL-3.0), services/Weather.qml.
Singleton {
    id: root
    readonly property string cacheFile: Quickshell.env("HOME") + "/.cache/aurora/weather.json"
    readonly property int every: 30 * 60 * 1000

    property var now: null       // {temp, feels, code, wind (km/h), humidity, rain (%), day}
    property var days: []        // [{date, code, max, min, rain, rise, set}], today first; dates are local
    property string place: ""    // city, when the lookup gave one
    property double fetched: 0   // Date.now() of the last good fetch
    property string error: ""    // why there is no weather
    readonly property bool ok: now !== null
    readonly property bool busy: where.running || get.running

    // coordinates and the Settings.weatherLoc they were resolved for
    property string key: ""
    property real lat: NaN
    property real lon: NaN

    readonly property var names: ({ 0: "clear", 1: "mostly clear", 2: "partly cloudy", 3: "overcast", 45: "fog", 48: "fog",
        51: "drizzle", 53: "drizzle", 55: "drizzle", 56: "ice drizzle", 57: "ice drizzle", 61: "light rain", 63: "rain",
        65: "heavy rain", 66: "ice rain", 67: "ice rain", 71: "light snow", 73: "snow", 75: "heavy snow", 77: "snow grains",
        80: "showers", 81: "showers", 82: "storm showers", 85: "snow showers", 86: "snow showers", 95: "thunder",
        96: "thunder", 99: "thunder" })
    function name(code) { return names[code] !== undefined ? names[code] : "weather" }
    function icon(code, day) {
        if (code <= 1) return day === false ? Theme.iNight : Theme.iSunny
        if (code === 2) return day === false ? Theme.iNightCloudy : Theme.iPartlyCloudy
        if (code === 3) return Theme.iCloudy
        if (code < 50) return Theme.iFog
        if (code >= 95) return Theme.iThunder
        if ((code >= 71 && code <= 77) || code === 85 || code === 86) return Theme.iSnow
        if (code === 65 || code === 82) return Theme.iPouring
        return Theme.iRain
    }
    // the entry for date d's day, null if the forecast doesn't cover it
    function dayOf(d) {
        for (var i = 0; i < days.length; i++)
            if (days[i].date.toDateString() === d.toDateString()) return days[i]
        return null
    }
    // up to n days after d
    function after(d, n) {
        var out = [], end = new Date(d.getFullYear(), d.getMonth(), d.getDate() + 1)
        for (var i = 0; i < days.length && out.length < n; i++)
            if (days[i].date >= end) out.push(days[i])
        return out
    }

    function refresh() {
        if (busy) { later.restart(); return }
        var want = (Settings.weatherLoc || "").trim()
        if (want !== key || isNaN(lat)) resolve(want)
        else pull()
    }
    function poke() {
        if (!busy && Date.now() - fetched > every) refresh()
    }

    function resolve(want) {
        var m = want.match(/^(-?\d+(?:\.\d+)?)\s*,\s*(-?\d+(?:\.\d+)?)$/)
        if (m) {
            key = want; lat = +m[1]; lon = +m[2]; place = ""
            pull()
            return
        }
        where.want = want
        where.command = want === ""
            ? ["curl", "-sf", "--max-time", "10", "https://ipinfo.io/json"]
            : ["curl", "-sfG", "--max-time", "10", "--data-urlencode", "name=" + want, "-d", "count=1",
               "https://geocoding-api.open-meteo.com/v1/search"]
        where.running = true
    }
    Process {
        id: where
        property string want: ""
        stdout: StdioCollector {
            onStreamFinished: {
                var j
                try { j = JSON.parse(text) } catch (e) { return }
                var w = where.want
                if (w === "") {
                    var p = String(j.loc || "").split(",")
                    if (p.length !== 2 || isNaN(+p[0]) || isNaN(+p[1])) return
                    root.lat = +p[0]; root.lon = +p[1]; root.place = j.city || ""
                } else {
                    if (!j.results || !j.results.length) { root.error = "no place called " + w; return }
                    var r = j.results[0]
                    root.lat = r.latitude; root.lon = r.longitude; root.place = r.name || w
                }
                root.key = w
                root.pull()
            }
        }
        onExited: code => { if (code !== 0) { root.error = "offline"; retry.restart() } }
    }

    function pull() {
        get.command = ["curl", "-sf", "--max-time", "15", "https://api.open-meteo.com/v1/forecast?latitude=" + lat + "&longitude=" + lon
            + "&current=temperature_2m,apparent_temperature,weather_code,wind_speed_10m,relative_humidity_2m,precipitation_probability,is_day"
            + "&daily=weather_code,temperature_2m_max,temperature_2m_min,sunrise,sunset,precipitation_probability_max"
            + "&timezone=auto&forecast_days=6"]
        get.running = true
    }
    Process {
        id: get
        stdout: StdioCollector {
            onStreamFinished: {
                var j
                try { j = JSON.parse(text) } catch (e) { return }
                if (!root.parse(j)) return
                root.fetched = Date.now()
                root.error = ""
                cache.setText(JSON.stringify({ key: root.key, lat: root.lat, lon: root.lon, place: root.place,
                                               fetched: root.fetched, raw: j }))
            }
        }
        onExited: code => { if (code !== 0) { root.error = "offline"; retry.restart() } }
    }

    // open-meteo's times have no offset ("2026-10-29T06:32", in the place's zone): JS reads them as local time
    function parse(j) {
        var c = j.current, d = j.daily
        if (!c || !d || !d.time) return false
        now = { temp: c.temperature_2m, feels: c.apparent_temperature, code: c.weather_code, wind: c.wind_speed_10m,
                humidity: c.relative_humidity_2m, rain: c.precipitation_probability, day: c.is_day === 1 }
        var out = []
        for (var i = 0; i < d.time.length; i++)
            out.push({ date: new Date(d.time[i] + "T00:00"), code: d.weather_code[i], max: d.temperature_2m_max[i],
                       min: d.temperature_2m_min[i], rain: d.precipitation_probability_max[i],
                       rise: new Date(d.sunrise[i]), set: new Date(d.sunset[i]) })
        days = out
        return true
    }

    property bool started: false
    FileView {
        id: cache
        path: root.cacheFile
        printErrors: false
        onLoaded: {
            if (root.started) return
            root.started = true
            try {
                var c = JSON.parse(text())
                if (root.parse(c.raw)) {
                    root.key = c.key; root.lat = c.lat; root.lon = c.lon; root.place = c.place || ""; root.fetched = c.fetched
                }
            } catch (e) {}
            if (root.key !== (Settings.weatherLoc || "").trim() || Date.now() - root.fetched > root.every) root.refresh()
        }
        onLoadFailed: { if (!root.started) { root.started = true; root.refresh() } }
    }

    Connections {
        target: Settings
        function onWeatherLocChanged() { if (root.started) root.refresh() }
    }
    Timer { id: retry; interval: 120000; onTriggered: root.refresh() }
    Timer { id: later; interval: 3000; onTriggered: root.refresh() }
    Timer { interval: root.every; running: true; repeat: true; onTriggered: root.refresh() }
}
