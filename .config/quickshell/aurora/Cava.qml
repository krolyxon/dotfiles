pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris

// Audio spectrum from cava (raw ascii output on stdout). Only runs while an MPRIS player is
// playing and something wants it (`wanted`), so it costs nothing when idle. Hidden if cava is missing.
Singleton {
    id: root
    readonly property int bars: Math.max(8, Settings.vizBars)
    readonly property bool wanted: Settings.desktopViz
    property bool available: false
    property var values: []                  // 0..1 per bar

    function anyPlaying() {
        var l = Mpris.players.values
        for (var i = 0; i < l.length; i++) if (l[i].isPlaying) return true
        return false
    }
    readonly property bool playing: anyPlaying()
    readonly property bool active: available && wanted && playing
    onActiveChanged: if (!active) idle.restart()

    readonly property string conf:
        "[general]\nbars = " + bars + "\nframerate = 60\nsleep_timer = 3\n" +
        "[input]\nmethod = pipewire\nsource = auto\n" +
        "[output]\nmethod = raw\nraw_target = /dev/stdout\nchannels = mono\n" +
        "data_format = ascii\nascii_max_range = 1000\nbar_delimiter = 59\nframe_delimiter = 10\n" +
        "[smoothing]\nnoise_reduction = 70\n"

    Process {
        command: ["sh", "-c", "command -v cava"]
        running: true
        onExited: code => root.available = code === 0
    }

    Process {
        id: proc
        running: root.active
        command: ["sh", "-c", 'mkdir -p "${2%/*}" && printf "%s" "$1" > "$2" && exec cava -p "$2"',
                  "sh", root.conf, Quickshell.env("HOME") + "/.cache/aurora/cava.conf"]
        stdout: SplitParser {
            onRead: line => {
                var p = line.split(";"), out = []
                for (var i = 0; i < p.length; i++) if (p[i] !== "") out.push(parseInt(p[i]) / 1000)
                root.values = out
            }
        }
    }
    // let the bars fall to zero once cava stops instead of freezing mid-frame
    Timer { id: idle; interval: 50; onTriggered: root.values = [] }
}
