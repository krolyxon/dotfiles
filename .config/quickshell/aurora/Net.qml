pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Wi-Fi backend: thin wrapper over nmcli (NetworkManager).
Singleton {
    id: root

    property bool active: false          // NetPage sets this while visible (faster polling + rescan)
    property var wiredDevs: []           // [{dev, name, ip, usb}] connected ethernet-type devices (incl. USB tethering)
    readonly property bool wired: wiredDevs.length > 0
    readonly property string wiredIcon: wiredDevs.length > 0 && wiredDevs[0].usb ? Theme.iPhone : Theme.iEthernet
    property bool wifiEnabled: true
    property string wifiDevice: ""
    property var raw: []                 // [{inUse, ssid, signal, security}]
    property var savedNames: []
    property string askFor: ""           // ssid currently asking for a password
    property string message: ""
    property bool busy: false
    property bool scanning: false

    property string lastSsid: ""
    property bool lastWasNew: false

    readonly property var networks: build(raw, savedNames)
    readonly property int activeSignal: {
        for (var i = 0; i < raw.length; i++) if (raw[i].inUse) return raw[i].signal
        return 0
    }
    readonly property string connected: {
        for (var i = 0; i < raw.length; i++) if (raw[i].inUse) return raw[i].ssid
        return ""
    }

    // ---- captive portal ----------------------------------------------
    // NetworkManager's connectivity check (`nmcli monitor`) says *that* there is a portal; a curl probe
    // finds *where* (the redirect). Opening the real URL matters: librewolf's HTTPS-only mode upgrades a
    // plain http:// test page, so the portal never gets to intercept it.
    readonly property string probeUrl: "http://connectivitycheck.gstatic.com/generate_204"
    property string connectivity: "unknown"   // none | portal | limited | full | unknown
    property bool portalProbed: false          // the probe got hijacked (also catches portals NM calls "limited")
    property string portalUrl: ""
    property string portalSeen: ""             // connection we already opened/notified for (once per connection)
    property bool probeManual: false           // signIn() asked: report "already online" too
    readonly property bool portal: connectivity === "portal" || portalProbed
    readonly property string portalNet: connected !== "" ? connected : (wiredDevs.length > 0 ? wiredDevs[0].name : "")

    onPortalNetChanged: if (portalNet !== "") checkNow()

    function checkNow() { if (!checkProc.running) checkProc.running = true }

    function gotConnectivity(s) {
        if (s === "") return
        var changed = s !== connectivity
        connectivity = s
        if (s === "portal" || s === "limited") {
            if (changed || (portalNet !== "" && portalSeen !== portalNet)) probe(false)
        } else {
            if (s === "full" && portalUrl !== "")
                Quickshell.execDetached(["notify-send", "-a", "aurora", "-i", "network-wireless", "online",
                                         (portalNet !== "" ? portalNet + ": " : "") + "signed in"])
            portalProbed = false
            portalUrl = ""
            portalSeen = ""         // next portal (even on the same network) opens again
        }
    }

    function probe(manual) {
        if (manual) probeManual = true
        if (!probeProc.running) probeProc.running = true
    }

    function gotProbe(text) {
        var m = /^(\d+) ?(.*)$/.exec(text.trim()), code = m ? m[1] : "000", url = m ? m[2] : ""
        var manual = probeManual
        probeManual = false
        if (code === "204") {
            portalProbed = false
            if (connectivity !== "full") checkNow()
            if (manual) Quickshell.execDetached(["notify-send", "-a", "aurora", "-i", "network-wireless", "already online", "no captive portal"])
            return
        }
        if (code === "000") {
            if (manual) Quickshell.execDetached(["notify-send", "-a", "aurora", "-i", "network-error", "no connection", "couldn't reach the network"])
            return
        }
        portalProbed = true
        portalUrl = url !== "" ? url : probeUrl     // 200 without a redirect: let the portal hijack the test page
        if (manual) { openPortal(); return }
        if (portalSeen === portalNet) return
        portalSeen = portalNet
        if (Settings.portalAutoOpen) openPortal()
        Quickshell.execDetached(["notify-send", "-a", "aurora", "-i", "network-wireless-acquiring",
                                 "sign in to " + (portalNet !== "" ? portalNet : "network"), portalUrl])
    }

    function openPortal() {
        Session.launch(["sh", "-c", 'exec ${BROWSER:-xdg-open} "$1"', "sh", portalUrl !== "" ? portalUrl : probeUrl])
    }

    // manual "sign in" (IPC): open the portal if there is one, else say why not
    function signIn() {
        if (portal && portalUrl !== "") openPortal()
        else probe(true)
    }

    onActiveChanged: if (active) { askFor = ""; message = ""; rescan() }

    // nmcli -t output: ':' separates fields, '\:' and '\\' are escapes
    function parseTerse(line) {
        var out = [], cur = ""
        for (var i = 0; i < line.length; i++) {
            var ch = line[i]
            if (ch === "\\" && i + 1 < line.length) { cur += line[i + 1]; i++ }
            else if (ch === ":") { out.push(cur); cur = "" }
            else cur += ch
        }
        out.push(cur)
        return out
    }

    // `nmcli device show` output (terse): one block per device, blank line between.
    // Android USB tethering (and USB ethernet dongles) show up as type "ethernet".
    function parseShow(text) {
        var devs = [], cur = null, lines = text.split("\n")
        for (var i = 0; i < lines.length; i++) {
            if (lines[i] === "") continue
            var f = parseTerse(lines[i]), key = f[0], val = f.slice(1).join(":")
            if (key === "GENERAL.DEVICE") { cur = { dev: val, type: "", state: "", name: "", ip: "" }; devs.push(cur) }
            else if (cur === null) continue
            else if (key === "GENERAL.TYPE") cur.type = val
            else if (key === "GENERAL.STATE") cur.state = val
            else if (key === "GENERAL.CONNECTION") cur.name = val
            else if (key.indexOf("IP4.ADDRESS") === 0 && cur.ip === "") cur.ip = val
        }
        var wired = []
        for (var j = 0; j < devs.length; j++) {
            var d = devs[j]
            if (d.type === "wifi") wifiDevice = d.dev
            var up = d.state.indexOf("connected") >= 0 && d.state.indexOf("disconnected") < 0
            if (d.type === "ethernet" && up)
                wired.push({
                    dev: d.dev, name: d.name !== "" ? d.name : d.dev, ip: d.ip,
                    usb: /^usb|^enx|u\d+(c\d+)?(i\d+)?$/.test(d.dev)
                })
        }
        wiredDevs = wired
    }

    function build(list, saved) {
        var out = []
        for (var i = 0; i < list.length; i++) {
            var n = list[i]
            out.push({
                ssid: n.ssid, signal: n.signal, security: n.security, inUse: n.inUse,
                saved: saved.indexOf(n.ssid) >= 0
            })
        }
        out.sort(function (a, b) {
            if (a.inUse !== b.inUse) return a.inUse ? -1 : 1
            return b.signal - a.signal
        })
        return out
    }

    function refresh() {
        radioProc.running = true
        devProc.running = true
        savedProc.running = true
        listProc.running = true
        connProc.running = true
    }

    function rescan() {
        scanning = true
        rescanProc.running = true
        refresh()
    }

    // ---- actions ------------------------------------------------------
    function run(args) {
        if (busy) return
        busy = true
        runProc.command = ["sh", "-c",
            'out=$(nmcli "$@" 2>&1); rc=$?; printf "%s\\n%d" "$out" "$rc"', "sh"].concat(args)
        runProc.running = true
    }

    function finish(text) {
        busy = false
        var lines = text.split("\n")
        var rc = parseInt(lines.pop())
        var out = lines.join(" ").trim()
        if (rc !== 0) {
            message = out
            // a failed first-time connect (wrong password: rc 4) leaves a broken profile behind; drop it.
            // Not on a timeout (rc 3): NM is still activating (slow campus DHCP) and deleting would abort it.
            if (rc === 4 && lastWasNew && lastSsid !== "")
                Quickshell.execDetached(["nmcli", "connection", "delete", "id", lastSsid])
        } else {
            message = ""
            askFor = ""
            checkNow()      // NM checks on activation too; this just makes the portal pop up sooner
        }
        lastWasNew = false
        refresh()
    }

    function connectTo(entry) {
        if (entry.inUse) return
        if (entry.saved || entry.security === "" || entry.security === "--") connect(entry.ssid, "")
        else askFor = (askFor === entry.ssid) ? "" : entry.ssid
    }

    function connect(ssid, password) {
        message = ""
        lastSsid = ssid
        var isSaved = savedNames.indexOf(ssid) >= 0
        if (isSaved && !password) {
            lastWasNew = false
            run(["connection", "up", "id", ssid])
        } else {
            lastWasNew = !isSaved
            var cmd = ["--wait", "60", "device", "wifi", "connect", ssid]
            if (password) cmd = cmd.concat(["password", password])
            run(cmd)
        }
    }

    function disconnectDev(dev) { run(["device", "disconnect", dev]) }
    function disconnect() { if (wifiDevice !== "") run(["device", "disconnect", wifiDevice]) }
    function forget(ssid) { run(["connection", "delete", "id", ssid]) }
    function setWifi(on) { run(["radio", "wifi", on ? "on" : "off"]) }

    // ---- processes ----------------------------------------------------
    // always on (the bar shows wifi state); quicker while the Net tab is open
    Timer {
        interval: root.active ? 10000 : 30000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }

    // connectivity events; restarted if nmcli exits (NM restart)
    Process {
        id: monitorProc
        running: true
        command: ["nmcli", "monitor"]
        stdout: SplitParser {
            onRead: line => {
                var m = /Connectivity is now '(\w+)'/.exec(line)
                if (m) root.gotConnectivity(m[1])
            }
        }
        onExited: monitorRestart.start()
    }
    Timer { id: monitorRestart; interval: 5000; onTriggered: monitorProc.running = true }

    // NM only re-checks every 300s: poll while stuck behind a portal so "signed in" shows up quickly
    Timer {
        interval: 5000
        running: root.portal
        repeat: true
        onTriggered: root.checkNow()
    }

    Process {
        id: connProc
        command: ["nmcli", "-t", "-f", "CONNECTIVITY", "general"]
        stdout: StdioCollector { onStreamFinished: root.gotConnectivity(text.trim()) }
    }

    Process {
        id: checkProc
        command: ["nmcli", "networking", "connectivity", "check"]
        stdout: StdioCollector { onStreamFinished: root.gotConnectivity(text.trim()) }
    }

    Process {
        id: probeProc
        command: ["curl", "-s", "-o", "/dev/null", "--max-time", "5", "-w", "%{http_code} %{redirect_url}", root.probeUrl]
        stdout: StdioCollector { onStreamFinished: root.gotProbe(text) }
    }

    Process {
        id: runProc
        stdout: StdioCollector { onStreamFinished: root.finish(text) }
    }

    Process {
        id: rescanProc
        command: ["nmcli", "device", "wifi", "rescan"]
        onExited: { root.scanning = false; listProc.running = true }
    }

    Process {
        id: radioProc
        command: ["nmcli", "radio", "wifi"]
        stdout: StdioCollector { onStreamFinished: root.wifiEnabled = text.trim() === "enabled" }
    }

    Process {
        id: devProc
        command: ["nmcli", "-t", "-f", "GENERAL.DEVICE,GENERAL.TYPE,GENERAL.STATE,GENERAL.CONNECTION,IP4.ADDRESS", "device", "show"]
        stdout: StdioCollector { onStreamFinished: root.parseShow(text) }
    }

    Process {
        id: savedProc
        command: ["nmcli", "-t", "-f", "NAME,TYPE", "connection", "show"]
        stdout: StdioCollector {
            onStreamFinished: {
                var out = [], lines = text.split("\n")
                for (var i = 0; i < lines.length; i++) {
                    var f = root.parseTerse(lines[i])
                    if (f.length >= 2 && f[1].indexOf("wireless") >= 0) out.push(f[0])
                }
                root.savedNames = out
            }
        }
    }

    // --rescan no: a plain `wifi list` starts a full scan when the last one is >30s old, i.e. on every
    // poll. Constant scans make the card roam (5 GHz -> weak 2.4 GHz), which drops the DHCP lease
    // behind captive portals. Scans only come from rescan() (Net tab opened / button) and NM itself.
    Process {
        id: listProc
        command: ["nmcli", "-t", "-f", "IN-USE,SSID,SIGNAL,SECURITY", "device", "wifi", "list", "--rescan", "no"]
        stdout: StdioCollector {
            onStreamFinished: {
                var best = {}, lines = text.split("\n")
                for (var i = 0; i < lines.length; i++) {
                    var f = root.parseTerse(lines[i])
                    if (f.length < 4 || f[1] === "") continue
                    var e = { inUse: f[0] === "*", ssid: f[1], signal: parseInt(f[2]) || 0, security: f[3] }
                    var o = best[e.ssid]
                    if (!o || e.inUse || (!o.inUse && e.signal > o.signal)) best[e.ssid] = e
                }
                var out = []
                for (var k in best) out.push(best[k])
                root.raw = out
            }
        }
    }
}
