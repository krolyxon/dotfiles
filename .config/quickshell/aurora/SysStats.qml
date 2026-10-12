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
    property real diskUsed: 0
    property real diskTotal: 0
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

    Process {
        id: dfProc
        command: ["df", "-B1", "--output=used,size", "/"]
        stdout: StdioCollector {
            onStreamFinished: {
                var l = text.trim().split("\n")
                if (l.length < 2) return
                var p = l[1].trim().split(/\s+/)
                root.diskUsed = parseFloat(p[0]) / 1073741824
                root.diskTotal = parseFloat(p[1]) / 1073741824
            }
        }
    }
    Timer { interval: 30000; running: true; repeat: true; triggeredOnStart: true; onTriggered: dfProc.running = true }
}
