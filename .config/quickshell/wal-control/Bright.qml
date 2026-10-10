pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Backlight via brightnessctl. Hides itself if brightnessctl isn't installed.
Singleton {
    id: root
    property int percent: -1
    readonly property bool available: percent >= 0
    property int pending: -1

    function refresh() { getProc.running = true }
    function setPercent(v) {
        percent = Math.round(v)
        pending = percent
        debounce.restart()
    }

    Timer {
        id: debounce
        interval: 70
        onTriggered: {
            if (setProc.running) { debounce.restart(); return }
            setProc.command = ["brightnessctl", "set", Math.max(1, root.pending) + "%"]
            setProc.running = true
        }
    }
    Process { id: setProc }
    Process {
        id: getProc
        command: ["brightnessctl", "-m"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                var p = text.trim().split(",")
                if (p.length >= 4) root.percent = parseInt(p[3])
            }
        }
    }
}
