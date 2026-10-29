pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// cpu / memory / disk / uptime. Shared by the cat, the bar and the System tab.
Singleton {
    id: root
    property real cpu: 0                 // 0..1
    property real memUsed: 0             // GiB
    property real memTotal: 0
    property var disks: []               // [{source, target, label, used, size}] in GiB, "/" first
    property real uptime: 0              // seconds
    property var history: []             // last 40 cpu samples
    property real prevIdle: -1
    property real prevTotal: 0

    FileView { id: statFile; path: "/proc/stat"; blockLoading: true }
    FileView { id: memFile; path: "/proc/meminfo"; blockLoading: true }
    FileView { id: upFile; path: "/proc/uptime"; blockLoading: true }

    function sample() {
        statFile.reload()
        var m = statFile.text().match(/^cpu\s+(.*)$/m)
        if (m) {
            var f = m[1].trim().split(/\s+/).map(Number)
            var idle = f[3] + (f[4] || 0)
            var total = 0
            for (var i = 0; i < Math.min(8, f.length); i++) total += f[i]
            if (prevIdle >= 0 && total > prevTotal)
                cpu = Math.max(0, Math.min(1, 1 - (idle - prevIdle) / (total - prevTotal)))
            prevIdle = idle
            prevTotal = total
            var h = history.slice()
            h.push(cpu)
            if (h.length > 40) h.shift()
            history = h
        }

        memFile.reload()
        var mt = memFile.text()
        var t = mt.match(/MemTotal:\s+(\d+)/), a = mt.match(/MemAvailable:\s+(\d+)/)
        if (t && a) {
            memTotal = parseInt(t[1]) / 1048576
            memUsed = (parseInt(t[1]) - parseInt(a[1])) / 1048576
        }

        upFile.reload()
        uptime = parseFloat(upFile.text().split(" ")[0]) || 0
    }

    Timer { interval: 1000; running: true; repeat: true; triggeredOnStart: true; onTriggered: root.sample() }

    // ---- details for the calendar dashboard: sampled every 2s, only while `detailed` (CalPopup sets it while open) ----
    // After glyph-rice (github.com/Nebelung-cloud/glyph-rice, GPL-3.0), services/SysStats.qml.
    property bool detailed: false
    property var cores: []               // 0..1 per thread
    property real cpuTemp: 0             // °C, 0 = no sensor found
    property real cpuFreq: 0             // GHz, average over threads
    property string gpuDev: ""           // the nvidia card in sysfs; "" = none (integrated mode, or no nvidia-smi)
    property bool gpuAwake: false        // not runtime-suspended
    property real gpu: 0                 // 0..1
    property real gpuTemp: 0
    property string iface: ""            // interface of the default route
    property real rx: 0                  // bytes/s
    property real tx: 0
    property var netHistory: []          // last 20 [rx, tx]
    property var procs: []               // top 4 [name, % of one thread] (processes with the same name summed)
    property string tempPath: ""
    property var corePrev: ({})
    property var netPrev: null           // [rx, tx, ms, iface]
    property var procPrev: ({})          // pid -> cpu ticks
    property double procAt: 0

    FileView { id: tempFile; path: root.tempPath; blockLoading: true; printErrors: false }
    FileView { id: infoFile; path: "/proc/cpuinfo"; blockLoading: true }
    FileView { id: routeFile; path: "/proc/net/route"; blockLoading: true }
    FileView { id: devFile; path: "/proc/net/dev"; blockLoading: true }
    FileView { id: gpuPm; path: root.gpuDev !== "" ? root.gpuDev + "/power/runtime_status" : ""; blockLoading: true; printErrors: false }

    // sensors by name (hwmonN numbers change between boots); the dGPU only if nvidia-smi can read it
    Process {
        running: true
        command: ["sh", "-c", 'for h in /sys/class/hwmon/hwmon*; do case "$(cat "$h/name" 2>/dev/null)" in '
            + 'coretemp|k10temp|zenpower|cpu_thermal) echo "temp $h/temp1_input"; break;; esac; done; '
            + 'command -v nvidia-smi >/dev/null && for d in /sys/bus/pci/drivers/nvidia/*:*; do [ -e "$d" ] && echo "gpu $d" && break; done']
        stdout: StdioCollector {
            onStreamFinished: {
                var l = text.trim().split("\n")
                for (var i = 0; i < l.length; i++) {
                    var s = l[i].indexOf(" ")
                    if (l[i].slice(0, s) === "temp") root.tempPath = l[i].slice(s + 1)
                    else if (l[i].slice(0, s) === "gpu") root.gpuDev = l[i].slice(s + 1)
                }
            }
        }
    }

    onDetailedChanged: {
        if (!detailed) return
        corePrev = {}; netPrev = null; procPrev = {}; netHistory = []
    }
    Timer { interval: 2000; running: root.detailed; repeat: true; triggeredOnStart: true; onTriggered: root.details() }

    function details() {
        statFile.reload()
        var lines = statFile.text().split("\n"), next = {}, out = []
        for (var i = 0; i < lines.length; i++) {
            var m = lines[i].match(/^cpu(\d+)\s+(.*)$/)
            if (!m) continue
            var f = m[2].trim().split(/\s+/).map(Number)
            var idle = f[3] + (f[4] || 0), total = 0
            for (var k = 0; k < Math.min(8, f.length); k++) total += f[k]
            var p = corePrev[m[1]]
            out.push(p && total > p[1] ? Math.max(0, Math.min(1, 1 - (idle - p[0]) / (total - p[1]))) : 0)
            next[m[1]] = [idle, total]
        }
        corePrev = next
        cores = out

        if (tempPath !== "") { tempFile.reload(); cpuTemp = (parseInt(tempFile.text()) || 0) / 1000 }
        infoFile.reload()
        var mhz = infoFile.text().match(/^cpu MHz\s*:\s*[\d.]+/gm) || [], sum = 0
        for (var j = 0; j < mhz.length; j++) sum += parseFloat(mhz[j].split(":")[1])
        cpuFreq = mhz.length ? sum / mhz.length / 1000 : 0

        // a sleeping dGPU idles: never wake it (nvidia-smi would, and polling keeps it awake)
        if (gpuDev !== "") {
            gpuPm.reload()
            gpuAwake = gpuPm.text().indexOf("suspend") !== 0
            if (gpuAwake) { if (!nvsmi.running) nvsmi.running = true }
            else { gpu = 0; gpuTemp = 0 }
        }

        // net: bytes of the default route's interface
        routeFile.reload()
        var r = routeFile.text().split("\n"), dev = ""
        for (var a = 1; a < r.length; a++) {
            var c = r[a].split("\t")
            if (c[1] === "00000000") { dev = c[0]; break }
        }
        iface = dev
        devFile.reload()
        var d = devFile.text().split("\n"), now = Date.now(), got = false
        for (var b = 0; b < d.length && dev !== ""; b++) {
            var s = d[b].indexOf(":")
            if (s < 0 || d[b].slice(0, s).trim() !== dev) continue
            var v = d[b].slice(s + 1).trim().split(/\s+/).map(Number)
            if (netPrev && netPrev[3] === dev && now > netPrev[2]) {
                rx = Math.max(0, (v[0] - netPrev[0]) / ((now - netPrev[2]) / 1000))
                tx = Math.max(0, (v[8] - netPrev[1]) / ((now - netPrev[2]) / 1000))
            }
            netPrev = [v[0], v[8], now, dev]
            got = true
            break
        }
        if (!got) { rx = 0; tx = 0; netPrev = null }
        var h = netHistory.slice()
        h.push([rx, tx])
        if (h.length > 20) h.shift()
        netHistory = h

        if (!procProc.running) procProc.running = true
    }

    Process {
        id: nvsmi
        command: ["nvidia-smi", "--query-gpu=utilization.gpu,temperature.gpu", "--format=csv,noheader,nounits"]
        stdout: StdioCollector {
            onStreamFinished: {
                var v = text.trim().split("\n")[0].split(",").map(Number)
                if (v.length < 2 || isNaN(v[0])) return
                root.gpu = v[0] / 100
                root.gpuTemp = v[1]
            }
        }
    }

    // current cpu use per process name: utime + stime deltas from /proc/<pid>/stat (ps only knows lifetime averages)
    Process {
        id: procProc
        command: ["sh", "-c", "cat /proc/[0-9]*/stat 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                var l = text.split("\n"), now = Date.now(), dt = (now - root.procAt) / 1000
                var prev = root.procPrev, cur = {}, by = {}
                for (var i = 0; i < l.length; i++) {
                    var a = l[i].indexOf(" ("), b = l[i].lastIndexOf(") ")
                    if (a < 0 || b < a) continue
                    var pid = l[i].slice(0, a), f = l[i].slice(b + 2).split(" ")
                    var ticks = (+f[11]) + (+f[12])
                    cur[pid] = ticks
                    if (prev[pid] === undefined) continue
                    var n = l[i].slice(a + 2, b)
                    by[n] = (by[n] || 0) + ticks - prev[pid]
                }
                var out = []
                if (root.procAt > 0 && dt > 0)
                    for (var k in by) if (by[k] > 0) out.push([k, by[k] / dt])     // 100 ticks/s = 100%
                out.sort(function (x, y) { return y[1] - x[1] })
                root.procs = out.slice(0, 4)
                root.procPrev = cur
                root.procAt = now
            }
        }
    }

    function rate(b) {                   // bytes/s -> [number, unit]
        if (b >= 1048576) return [(b / 1048576).toFixed(b >= 10485760 ? 0 : 1), "mb/s"]
        return [String(Math.round(b / 1024)), "kb/s"]
    }

    // every mounted *local* block device (internal nvme, external drives, usb sticks...).
    // pseudo filesystems and network mounts are skipped; one entry per physical source
    // (so btrfs subvolumes / bind mounts of the same partition don't repeat).
    function refreshDisks() { dfProc.running = true }

    function parseDf(text) {
        var lines = text.split("\n"), seen = {}, out = []
        for (var i = 1; i < lines.length; i++) {
            var m = lines[i].match(/^(\S+)\s+(\d+)\s+(\d+)\s+(.*)$/)
            if (!m) continue
            var src = m[1], target = m[4].trim()
            if (src.indexOf("/dev/") !== 0 || src.indexOf("/dev/loop") === 0) continue
            if (target.indexOf("/boot") === 0 || target.indexOf("/efi") === 0 || target.indexOf("/var/lib") === 0) continue
            if (seen[src]) continue
            seen[src] = true
            var size = parseFloat(m[3])
            if (size <= 0) continue
            var parts = target.split("/").filter(function (x) { return x !== "" })
            out.push({
                source: src, target: target,
                label: parts.length ? parts[parts.length - 1] : "/",
                used: parseFloat(m[2]) / 1073741824, size: size / 1073741824
            })
        }
        out.sort(function (a, b) {
            if (a.target === "/") return -1
            if (b.target === "/") return 1
            return a.target.localeCompare(b.target)
        })
        return out
    }

    Process {
        id: dfProc
        command: ["df", "-l", "-B1", "--output=source,used,size,target"]
        stdout: StdioCollector { onStreamFinished: root.disks = root.parseDf(text) }
    }
    Timer { interval: 30000; running: true; repeat: true; triggeredOnStart: true; onTriggered: root.refreshDisks() }
}
