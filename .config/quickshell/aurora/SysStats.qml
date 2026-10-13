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
