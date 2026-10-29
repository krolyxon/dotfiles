import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland

// Calendar dashboard under the bar clock (top centre): one card, sections split by dotted lines:
// month calendar | weather (now, next 4 days, daylight) | system (cpu/mem/gpu rings, top processes, threads) | net | media.
// Calendar: Monday first, ISO week numbers, today in a primary circle. Scroll over it / arrows change the month,
// up / down the year, space = back to today, Esc closes. SysStats samples its details only while this is open.
// After glyph-rice (github.com/Nebelung-cloud/glyph-rice, GPL-3.0), cal/Cal.qml and deck/Deck.qml.
PanelWindow {
    id: win
    property bool opened: false
    signal closeRequested()

    property real t: opened ? 1 : 0
    Behavior on t { NumberAnimation { duration: Theme.t; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.glide } }

    visible: t > 0
    anchors.top: true
    margins.top: 6
    implicitWidth: card.width
    implicitHeight: card.height + 20      // room for the slide
    exclusiveZone: 0
    color: "transparent"
    mask: Region { item: card }
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "aurora-calendar"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

    HyprlandFocusGrab {
        windows: [win]
        active: win.opened
        onCleared: win.closeRequested()
    }

    Binding { target: SysStats; property: "detailed"; value: win.opened }

    SystemClock { id: clock; precision: SystemClock.Minutes }
    readonly property var en: Qt.locale("en_US")
    readonly property var now: clock.date
    readonly property real h: calCol.implicitHeight     // every section is as tall as the calendar

    property int year: 0
    property int month: 0                 // 0..11
    function today() {
        var d = new Date()
        year = d.getFullYear()
        month = d.getMonth()
    }
    function shift(n) {
        var m = month + n
        year += Math.floor(m / 12)
        month = ((m % 12) + 12) % 12
    }
    onOpenedChanged: if (opened) { today(); Weather.poke() }

    function isoWeek(d) {
        var t = new Date(Date.UTC(d.getFullYear(), d.getMonth(), d.getDate()))
        var day = t.getUTCDay() || 7
        t.setUTCDate(t.getUTCDate() + 4 - day)
        var y0 = new Date(Date.UTC(t.getUTCFullYear(), 0, 1))
        return Math.ceil(((t - y0) / 86400000 + 1) / 7)
    }
    // 6 rows x 7 days starting on the Monday on/before the 1st
    readonly property var days: {
        var first = new Date(year, month, 1)
        var start = new Date(year, month, 1 - ((first.getDay() + 6) % 7))
        var out = []
        for (var i = 0; i < 42; i++)
            out.push(new Date(start.getFullYear(), start.getMonth(), start.getDate() + i))
        return out
    }
    function hm(d) { return Theme.hh(d) + ":" + Qt.formatDateTime(d, "mm") }

    // weather of today (sunrise/sunset) and the next days
    readonly property var wToday: Weather.dayOf(now)
    readonly property var wNext: Weather.after(now, 4)

    // MPRIS doesn't push position updates, so poke it while playing
    Timer {
        running: win.visible && Media.playing && Media.seekable
        interval: 500
        repeat: true
        onTriggered: Media.player.positionChanged()
    }

    Rectangle {
        id: card
        y: -16 * (1 - win.t)
        opacity: win.t
        width: row.width + 52
        height: row.height + 48
        radius: 36
        color: Theme.fade(Theme.s1, Theme.panelAlpha)
        border.width: 1
        border.color: Theme.s2
        focus: true
        Keys.onEscapePressed: win.closeRequested()
        Keys.onLeftPressed: win.shift(-1)
        Keys.onRightPressed: win.shift(1)
        Keys.onUpPressed: win.shift(-12)
        Keys.onDownPressed: win.shift(12)
        Keys.onSpacePressed: win.today()

        Row {
            id: row
            x: 26
            y: 24
            spacing: 22

            // ---------------- calendar ----------------
            Item {
                width: calCol.implicitWidth
                height: calCol.implicitHeight
                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.NoButton
                    onWheel: w => win.shift(w.angleDelta.y > 0 ? -1 : 1)
                }
                ColumnLayout {
                    id: calCol
                    width: 288
                    spacing: 0

                    Lb {
                        Layout.leftMargin: 6
                        px: 10
                        text: win.en.toString(win.now, "dddd · d MMMM") + " · week " + win.isoWeek(win.now)
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        Layout.topMargin: 12
                        Layout.leftMargin: 6
                        spacing: 10
                        Num {
                            text: win.en.standaloneMonthName(win.month, Locale.ShortFormat)
                            font.pixelSize: 44
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: win.today()
                            }
                        }
                        Lb {
                            Layout.alignment: Qt.AlignVCenter
                            text: win.year
                        }
                        Item { Layout.fillWidth: true }
                        IconBtn { implicitHeight: 36; icon: Theme.iChevronLeft; onClicked: win.shift(-1) }
                        IconBtn { implicitHeight: 36; icon: Theme.iChevron; onClicked: win.shift(1) }
                    }
                    Grid {
                        id: grid
                        Layout.fillWidth: true
                        Layout.topMargin: 12
                        columns: 8
                        readonly property real cw: calCol.width / 8

                        Repeater {
                            model: ["wk", "m", "t", "w", "t", "f", "s", "s"]
                            delegate: Lb {
                                required property var modelData
                                required property int index
                                width: grid.cw
                                height: 24
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                                text: modelData
                                px: 10
                                color: index === 0 ? Theme.mute : Theme.grey
                            }
                        }
                        Repeater {
                            model: 48
                            delegate: Item {
                                id: cell
                                required property int index
                                readonly property bool isWeek: index % 8 === 0
                                // week-number cells use that row's Monday
                                readonly property var d: win.days[Math.floor(index / 8) * 7 + Math.max(0, (index % 8) - 1)]
                                readonly property bool inMonth: d.getMonth() === win.month
                                readonly property bool isToday: !isWeek && d.toDateString() === win.now.toDateString()
                                readonly property bool weekend: (index % 8) >= 6
                                width: grid.cw
                                height: 34
                                Rectangle {
                                    visible: cell.isToday
                                    anchors.centerIn: parent
                                    width: 30
                                    height: 30
                                    radius: 15
                                    color: Theme.fill
                                }
                                Text {
                                    anchors.centerIn: parent
                                    text: cell.isWeek ? win.isoWeek(cell.d) : cell.d.getDate()
                                    color: cell.isToday ? Theme.fillFg
                                           : cell.isWeek ? Theme.mute
                                           : !cell.inMonth ? Theme.mute
                                           : cell.weekend ? Theme.grey : Theme.fg
                                    font.family: Theme.mono
                                    font.pixelSize: cell.isWeek ? 10 : 13
                                    font.bold: cell.isToday
                                }
                            }
                        }
                    }
                }
            }

            Sep { h: win.h }

            // ---------------- weather ----------------
            ColumnLayout {
                width: 208
                height: win.h
                spacing: 0

                Lb {
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                    px: 10
                    color: Weather.error !== "" && !Weather.ok ? Theme.err : Theme.grey
                    text: !Weather.ok ? (Weather.busy ? "looking outside" : Weather.error || "no weather")
                          : (Weather.place !== "" ? Weather.place + " · " : "") + Weather.name(Weather.now.code)
                }
                RowLayout {
                    Layout.topMargin: 14
                    spacing: 12
                    Icon {
                        text: Weather.ok ? Weather.icon(Weather.now.code, Weather.now.day) : Theme.iCloudy
                        font.pixelSize: 46
                        opacity: Weather.ok ? 1 : 0.4
                        layer.enabled: true
                        layer.effect: DotMask { step: 3 }
                    }
                    Num {
                        text: Weather.ok ? Math.round(Weather.now.temp) + "°" : "--"
                        font.pixelSize: 52
                    }
                }
                Lb {
                    Layout.topMargin: 12
                    visible: Weather.ok
                    px: 10
                    text: Weather.ok ? "feels " + Math.round(Weather.now.feels) + "° · " + Math.round(Weather.now.wind) + " km/h" : ""
                }
                Lb {
                    Layout.topMargin: 4
                    visible: Weather.ok
                    px: 10
                    text: Weather.ok ? "humid " + Math.round(Weather.now.humidity) + "% · rain " + Math.round(Weather.now.rain || 0) + "%" : ""
                }
                Item { Layout.fillHeight: true }
                Row {
                    spacing: 8
                    Repeater {
                        model: win.wNext
                        Column {
                            required property var modelData
                            width: 46
                            Lb {
                                anchors.horizontalCenter: parent.horizontalCenter
                                px: 10
                                text: win.en.toString(modelData.date, "ddd")
                            }
                            Icon {
                                anchors.horizontalCenter: parent.horizontalCenter
                                topPadding: lead + 6
                                text: Weather.icon(modelData.code, true)
                                font.pixelSize: 24
                                layer.enabled: true
                                layer.effect: DotMask { step: 2 }
                            }
                            Lb {
                                anchors.horizontalCenter: parent.horizontalCenter
                                topPadding: 6
                                px: 11
                                color: Theme.fg
                                text: Math.round(modelData.max) + "°"
                            }
                            Lb {
                                anchors.horizontalCenter: parent.horizontalCenter
                                px: 10
                                text: Math.round(modelData.min) + "°"
                            }
                        }
                    }
                }
                // daylight: lit from sunrise to now
                Seg {
                    Layout.fillWidth: true
                    Layout.topMargin: 16
                    Layout.preferredHeight: 6
                    n: 24
                    f: win.wToday ? (win.now - win.wToday.rise) / (win.wToday.set - win.wToday.rise) : 0
                }
                RowLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: 10
                    Meta { icon: Theme.iSunrise; text: win.wToday ? win.hm(win.wToday.rise) : "--:--" }
                    Item { Layout.fillWidth: true }
                    Meta { icon: Theme.iSunset; text: win.wToday ? win.hm(win.wToday.set) : "--:--" }
                }
            }

            Sep { h: win.h }

            // ---------------- system ----------------
            ColumnLayout {
                width: 320
                height: win.h
                spacing: 0

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 0
                    Gauge {
                        on: win.opened
                        f: SysStats.cpu
                        label: "cpu" + (SysStats.cpuTemp > 0 ? " · " + Math.round(SysStats.cpuTemp) + "°" : "")
                    }
                    Item { Layout.fillWidth: true }
                    Gauge {
                        on: win.opened
                        f: SysStats.memTotal > 0 ? SysStats.memUsed / SysStats.memTotal : 0
                        label: "mem · " + SysStats.memUsed.toFixed(1) + "g"
                    }
                    Item { Layout.fillWidth: true }
                    // the dGPU if there is one (asleep = idle, never woken for this), else the root disk
                    Gauge {
                        readonly property var disk: SysStats.disks.length ? SysStats.disks[0] : null
                        on: win.opened
                        f: SysStats.gpuDev !== "" ? SysStats.gpu : disk ? disk.used / disk.size : 0
                        label: SysStats.gpuDev === "" ? "disk · " + (disk ? disk.label : "")
                               : SysStats.gpuAwake ? "gpu · " + Math.round(SysStats.gpuTemp) + "°" : "gpu · asleep"
                    }
                }
                Item { Layout.fillHeight: true }
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 16
                    ColumnLayout {
                        Layout.preferredWidth: 160
                        Layout.alignment: Qt.AlignTop
                        spacing: 5
                        Lb { px: 10; text: "processes" }
                        Repeater {
                            model: SysStats.procs
                            RowLayout {
                                required property var modelData
                                spacing: 6
                                Lb {
                                    Layout.preferredWidth: 78
                                    elide: Text.ElideRight
                                    px: 10
                                    color: Theme.fg
                                    text: modelData[0]
                                }
                                Lb {
                                    Layout.preferredWidth: 34
                                    horizontalAlignment: Text.AlignRight
                                    px: 10
                                    text: Math.round(modelData[1]) + "%"
                                }
                                Seg {
                                    Layout.preferredWidth: 36
                                    Layout.preferredHeight: 5
                                    n: 6
                                    spacing: 3
                                    f: modelData[1] / 100
                                }
                            }
                        }
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignTop
                        spacing: 8
                        Lb {
                            px: 10
                            text: "threads" + (SysStats.cpuFreq > 0 ? " · " + SysStats.cpuFreq.toFixed(1) + " ghz" : "")
                        }
                        // a column per thread: the top dot is the level, the ones below it trail
                        Grid {
                            id: cores
                            readonly property int n: Math.max(1, SysStats.cores.length)
                            readonly property real d: (width - (n - 1) * spacing) / n
                            Layout.fillWidth: true
                            columns: n
                            spacing: 2
                            Repeater {
                                model: cores.n * 8
                                Rectangle {
                                    required property int index
                                    readonly property int up: 8 - Math.floor(index / cores.n)     // 8 top .. 1 bottom
                                    readonly property int lvl: Math.round(1 + 7 * (SysStats.cores[index % cores.n] || 0))
                                    width: cores.d
                                    height: cores.d
                                    radius: cores.d / 2
                                    color: up === lvl ? Theme.fill : up < lvl ? Theme.fade(Theme.fill, 0.4) : Theme.s3
                                }
                            }
                        }
                    }
                }
            }

            Sep { h: win.h }

            // ---------------- net ----------------
            ColumnLayout {
                width: 180
                height: win.h
                spacing: 0

                Lb {
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                    px: 10
                    text: "net · " + (Net.connected !== "" ? Net.connected : SysStats.iface !== "" ? SysStats.iface : "offline")
                }
                Speed { Layout.topMargin: 16; icon: Theme.iArrowDown; b: SysStats.rx }
                Speed { Layout.topMargin: 10; icon: Theme.iArrowUp; b: SysStats.tx }
                Item { Layout.fillHeight: true }
                // the last 40s: download grows up from the middle, upload (dimmer) down
                Grid {
                    id: hist
                    readonly property var pts: SysStats.netHistory
                    readonly property real peak: {
                        var p = 10240
                        for (var i = 0; i < pts.length; i++) p = Math.max(p, pts[i][0], pts[i][1])
                        return p
                    }
                    readonly property real d: (width - 19 * spacing) / 20
                    Layout.fillWidth: true
                    columns: 20
                    spacing: 3
                    Repeater {
                        model: 20 * 10
                        Rectangle {
                            required property int index
                            readonly property int r: Math.floor(index / 20)          // 0..9 top to bottom
                            readonly property bool up: r >= 5
                            readonly property var p: hist.pts[index % 20 - 20 + hist.pts.length] || [0, 0]
                            readonly property real v: up ? p[1] : p[0]
                            readonly property bool lit: v > 0 && (up ? r - 4 : 5 - r) <= Math.ceil(5 * v / hist.peak)
                            width: hist.d
                            height: hist.d
                            radius: hist.d / 2
                            color: lit ? (up ? Theme.grey : Theme.fill) : Theme.s3
                        }
                    }
                }
            }

            Sep { h: win.h; visible: Media.player !== null }

            // ---------------- media ----------------
            ColumnLayout {
                visible: Media.player !== null
                width: 250
                height: win.h
                spacing: 0

                Lb {
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                    px: 10
                    text: Media.player ? Media.player.identity : ""
                }
                RowLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: 16
                    spacing: 14
                    // the cover as dots, turning while it plays
                    DotArt {
                        Layout.preferredWidth: 84
                        Layout.preferredHeight: 84
                        step: 5
                        url: Media.player ? Media.player.trackArtUrl : ""
                        RotationAnimation on rotation {
                            from: 0
                            to: 360
                            duration: 14000
                            loops: Animation.Infinite
                            running: win.visible && Theme.motion
                            paused: running && !Media.playing
                        }
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2
                        Text {
                            Layout.fillWidth: true
                            wrapMode: Text.Wrap
                            maximumLineCount: 2
                            elide: Text.ElideRight
                            text: Media.player && Media.player.trackTitle ? Media.player.trackTitle : "nothing on"
                            color: Theme.fg
                            font.family: Theme.ui
                            font.pixelSize: 17
                            font.weight: Font.DemiBold
                        }
                        Text {
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                            text: Media.player ? Media.player.trackArtist : ""
                            color: Theme.fgDim
                            font.family: Theme.ui
                            font.pixelSize: 13
                        }
                    }
                }
                Item { Layout.fillHeight: true }
                Seg {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 6
                    n: 20
                    f: Media.seekable ? Media.player.position / Media.player.length : 0
                }
                RowLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: 8
                    Lb { px: 10; text: Media.seekable ? Media.fmt(Media.player.position) : "" }
                    Item { Layout.fillWidth: true }
                    Lb { px: 10; text: Media.seekable ? Media.fmt(Media.player.length) : "" }
                }
                PlayControls {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.topMargin: 12
                    size: 20
                    play: 48
                }
            }
        }
    }

    // dotted line between sections (inline components can't see the file's ids: everything comes in as properties)
    component Sep: Column {
        id: sep
        property real h
        spacing: 7
        Repeater {
            model: Math.floor((sep.h + 7) / 10)
            Rectangle { width: 3; height: 3; radius: 1.5; color: Theme.s3 }
        }
    }
    // dot ring with the percentage inside and a label under it; lights in a wave when the popup opens
    component Gauge: Column {
        id: g
        property real f
        property string label
        property bool on
        spacing: 8
        Item {
            anchors.horizontalCenter: parent.horizontalCenter
            width: 88
            height: 88
            Ring { anchors.fill: parent; anchors.margins: 2; n: 32; dot: 4; f: g.on ? g.f : 0 }
            Num { anchors.centerIn: parent; text: Math.round(g.f * 100); font.pixelSize: 30 }
        }
        Lb { anchors.horizontalCenter: parent.horizontalCenter; px: 10; text: g.label }
    }
    // arrow, Doto number, unit
    component Speed: RowLayout {
        id: sp
        property string icon
        property real b
        readonly property var v: SysStats.rate(b)
        spacing: 8
        Icon { text: sp.icon; font.pixelSize: 18 }
        Num { text: sp.v[0]; font.pixelSize: 44 }
        Lb { px: 10; text: sp.v[1] }
    }
    component Meta: RowLayout {
        id: m
        property string icon
        property string text
        spacing: 8
        Icon { text: m.icon; font.pixelSize: 16; color: Theme.grey }
        Lb { px: 10; text: m.text }
    }
}
