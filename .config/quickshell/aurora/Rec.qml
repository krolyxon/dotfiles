pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Services.Pipewire

// Screen recording with wf-recorder (the focused monitor, or a region via slurp), saved to ~/vids/rec.
// Records desktop audio: the monitor source of the current default output (whatever you hear).
// Two steps so each can be cancelled: `selecting` (slurp is up) then `running` (wf-recorder records).
// stop() works in both. Everything is hidden if wf-recorder / slurp aren't installed.
Singleton {
    id: root
    property bool available: false
    readonly property bool running: recProc.running
    readonly property bool selecting: delay.running || selectProc.running
    readonly property bool busy: running || selecting
    property string dir: Quickshell.env("HOME") + "/vids/recs"
    property string file: ""
    readonly property string log: Quickshell.env("HOME") + "/.cache/aurora/rec.log"
    property string mode: "screen"
    property int elapsed: 0                  // seconds

    function start(m) {                      // "region" | "screen"
        if (!available || busy) return
        mode = m
        delay.start()                        // let the panel close before slurp grabs the screen
    }
    function stop() {
        if (delay.running) delay.stop()
        if (selectProc.running) selectProc.signal(15)
        if (recProc.running) recProc.signal(2)    // SIGINT: wf-recorder finalises the file
    }
    function toggle(m) { if (busy) stop(); else start(m) }

    function record(geometry) {
        file = dir + "/" + Qt.formatDateTime(new Date(), "yyyy-MM-dd_HH-mm-ss") + ".mp4"
        var mon = Hyprland.focusedMonitor
        // exec so the Process pid is wf-recorder itself and SIGINT reaches it.
        // its (very chatty) output must go to a file: left on the Process pipe it dies without writing anything
        var sink = Pipewire.defaultAudioSink
        var audio = sink ? "--audio=" + sink.name + ".monitor" : "--audio"
        var run = 'mkdir -p "${1%/*}" "${3%/*}"; exec wf-recorder ' + (geometry !== "" ? '-g' : '-o') + ' "$2" "$4" -f "$1" >"$3" 2>&1'
        recProc.command = ["sh", "-c", run, "sh", file, geometry !== "" ? geometry : (mon ? mon.name : ""), log, audio]
        elapsed = 0
        recProc.running = true
    }

    Timer {
        id: delay
        interval: 250
        onTriggered: {
            if (root.mode === "region") selectProc.running = true
            else root.record("")
        }
    }
    Process {
        id: selectProc
        command: ["slurp"].concat(Theme.slurpArgs)
        // slurp prints nothing when cancelled (Esc, or stop() killing it)
        stdout: StdioCollector {
            onStreamFinished: {
                var g = text.trim()
                if (g !== "") root.record(g)
            }
        }
    }
    Process {
        id: recProc
        onExited: {
            Quickshell.execDetached(["sh", "-c",
                '[ -s "$1" ] && notify-send -a aurora "recording saved" "$1"', "sh", root.file])
        }
    }
    Timer { interval: 1000; repeat: true; running: recProc.running; onTriggered: root.elapsed++ }

    Process {
        command: ["sh", "-c", "command -v wf-recorder && command -v slurp"]
        running: true
        onExited: code => root.available = code === 0
    }
}
