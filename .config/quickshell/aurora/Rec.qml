pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

// Screen recording with wf-recorder (region via slurp, or the focused monitor), saved to ~/vids/rec.
// Everything is hidden if wf-recorder isn't installed.
Singleton {
    id: root
    property bool available: false
    readonly property bool running: proc.running
    property string dir: Quickshell.env("HOME") + "/vids/rec"
    property string file: ""
    property int elapsed: 0                  // seconds

    function start(mode) {                   // "region" | "screen"
        if (!available || proc.running) return
        file = dir + "/" + Qt.formatDateTime(new Date(), "yyyy-MM-dd_HH-mm-ss") + ".mp4"
        var m = Hyprland.focusedMonitor
        // exec so the Process pid is wf-recorder itself and SIGINT reaches it
        proc.command = mode === "region"
            ? ["sh", "-c", 'mkdir -p "${1%/*}"; g=$(slurp) || exit 1; exec wf-recorder -g "$g" -f "$1"', "sh", file]
            : ["sh", "-c", 'mkdir -p "${1%/*}"; exec wf-recorder -o "$2" -f "$1"', "sh", file, m ? m.name : ""]
        elapsed = 0
        proc.running = true
    }
    function stop() { if (proc.running) proc.signal(2) }   // SIGINT: wf-recorder finalises the file
    function toggle(mode) { if (proc.running) stop(); else start(mode) }

    Process {
        id: proc
        onExited: code => {
            Quickshell.execDetached(["sh", "-c",
                '[ -s "$1" ] && notify-send -a aurora "recording saved" "$1"', "sh", root.file])
        }
    }
    Timer { interval: 1000; repeat: true; running: proc.running; onTriggered: root.elapsed++ }

    Process {
        command: ["sh", "-c", "command -v wf-recorder && command -v slurp"]
        running: true
        onExited: code => root.available = code === 0
    }
}
