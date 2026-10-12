pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Mirrors your gpu_mode.sh (envycontrol -q) and can switch modes via pkexec.
Singleton {
    id: root
    property string mode: ""            // "" = envycontrol not available
    property string pending: ""         // mode queued, applies after reboot
    property string message: ""
    property bool busy: false
    property string target: ""

    function refresh() { query.running = true }
    function set(m) {
        if (busy) return
        busy = true
        message = ""
        target = m
        sw.command = ["pkexec", "envycontrol", "-s", m]
        sw.running = true
    }

    Process {
        id: query
        command: ["envycontrol", "-q"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                var w = text.trim().split(/\s+/)
                root.mode = w.length && w[0] !== "" ? w[w.length - 1] : ""
            }
        }
    }
    Process {
        id: sw
        stderr: StdioCollector { id: swErr }
        onExited: (code, status) => {
            root.busy = false
            if (code === 0) root.pending = root.target
            else root.message = "switch failed or cancelled"
            root.refresh()
        }
    }
}
