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

    property bool stepping: false
    signal stepped()                     // a step() finished and percent is fresh (drives the OSD)

    function refresh() { getProc.running = true }
    // media keys: ~/.local/bin/brictl picks laptop backlight vs ddcutil for the focused monitor;
    // plain brightnessctl if the script is missing
    function step(dir) {
        if (stepProc.running) return
        stepProc.command = ["sh", "-c",
            '[ -x "$1" ] && exec "$1" "$2"; exec brightnessctl -e4 -n2 set 5%"$2"',
            "sh", Quickshell.env("HOME") + "/.local/bin/brictl", dir > 0 ? "+" : "-"]
        stepProc.running = true
    }
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
        id: stepProc
        onExited: { root.stepping = true; getProc.running = true }
    }
    Process {
        id: getProc
        command: ["brightnessctl", "-m"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                var p = text.trim().split(",")
                if (p.length >= 4) root.percent = parseInt(p[3])
                if (root.stepping) { root.stepping = false; root.stepped() }
            }
        }
    }
}
