pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Clipboard history on top of cliphist (the wl-paste --watch cliphist store daemons from hyprland.lua).
// Hides its UI if cliphist isn't installed.
Singleton {
    id: root
    property bool available: false
    property var entries: []                 // [{id, text, image, fmt}], newest first
    property var ready: ({})                 // id -> true once its image preview is decoded
    readonly property string imgDir: Quickshell.env("HOME") + "/.cache/aurora/clip"

    function imageOf(e) { return imgDir + "/" + e.id + "." + e.fmt }

    function refresh() { if (available) listProc.running = true }
    function copy(id) {
        Quickshell.execDetached(["sh", "-c", 'cliphist decode "$1" | wl-copy', "sh", String(id)])
    }
    function remove(id) {
        delProc.command = ["sh", "-c", 'printf "%s\\t\\n" "$1" | cliphist delete', "sh", String(id)]
        delProc.running = true
        var out = []
        for (var i = 0; i < entries.length; i++) if (entries[i].id !== id) out.push(entries[i])
        entries = out
    }
    function wipe() {
        Quickshell.execDetached(["sh", "-c", 'cliphist wipe; rm -rf "$1"', "sh", imgDir])
        entries = []
        ready = {}
    }

    Process {
        command: ["sh", "-c", "command -v cliphist"]
        running: true
        onExited: code => root.available = code === 0
    }
    Process { id: delProc }

    Process {
        id: listProc
        command: ["cliphist", "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                var out = [], imgs = [], l = text.split("\n")
                for (var i = 0; i < l.length; i++) {
                    var t = l[i].indexOf("\t")
                    if (t <= 0) continue
                    var e = { id: l[i].substring(0, t), text: l[i].substring(t + 1), image: false, fmt: "" }
                    // images are listed as "[[ binary data 12 KiB png 100x100 ]]"
                    var m = e.text.match(/^\[\[ binary data .* (\w+) (\d+)x(\d+) \]\]$/)
                    if (m) {
                        e.image = true
                        e.fmt = m[1]
                        e.text = m[1] + "  " + m[2] + "x" + m[3]
                        imgs.push(e.id, root.imageOf(e))
                    }
                    out.push(e)
                }
                root.entries = out
                if (imgs.length) {
                    imgProc.command = ["sh", "-c",
                        'mkdir -p "$1"; shift; while [ $# -ge 2 ]; do ' +
                        '[ -s "$2" ] || cliphist decode "$1" > "$2"; [ -s "$2" ] && echo "$1"; shift 2; done',
                        "sh", root.imgDir].concat(imgs)
                    imgProc.running = true
                }
            }
        }
    }
    Process {
        id: imgProc
        stdout: StdioCollector {
            onStreamFinished: {
                var r = {}, l = text.split("\n")
                for (var i = 0; i < l.length; i++) if (l[i] !== "") r[l[i]] = true
                root.ready = r
            }
        }
    }
}
