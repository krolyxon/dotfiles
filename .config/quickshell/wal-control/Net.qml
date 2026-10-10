pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Wi-Fi backend: thin wrapper over nmcli (NetworkManager).
Singleton {
    id: root

    property bool active: false          // NetPage sets this while visible
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
    readonly property string connected: {
        for (var i = 0; i < raw.length; i++) if (raw[i].inUse) return raw[i].ssid
        return ""
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
            // a failed first-time connect leaves a broken profile behind; drop it
            if (lastWasNew && lastSsid !== "")
                Quickshell.execDetached(["nmcli", "connection", "delete", "id", lastSsid])
        } else {
            message = ""
            askFor = ""
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
            var cmd = ["--wait", "20", "device", "wifi", "connect", ssid]
            if (password) cmd = cmd.concat(["password", password])
            run(cmd)
        }
    }

    function disconnect() { if (wifiDevice !== "") run(["device", "disconnect", wifiDevice]) }
    function forget(ssid) { run(["connection", "delete", "id", ssid]) }
    function setWifi(on) { run(["radio", "wifi", on ? "on" : "off"]) }

    // ---- processes ----------------------------------------------------
    Timer {
        interval: 10000
        running: root.active
        repeat: true
        onTriggered: root.refresh()
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
        command: ["nmcli", "-t", "-f", "DEVICE,TYPE,STATE", "device"]
        stdout: StdioCollector {
            onStreamFinished: {
                var lines = text.split("\n")
                for (var i = 0; i < lines.length; i++) {
                    var f = root.parseTerse(lines[i])
                    if (f.length >= 2 && f[1] === "wifi") { root.wifiDevice = f[0]; return }
                }
            }
        }
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

    Process {
        id: listProc
        command: ["nmcli", "-t", "-f", "IN-USE,SSID,SIGNAL,SECURITY", "device", "wifi", "list"]
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
