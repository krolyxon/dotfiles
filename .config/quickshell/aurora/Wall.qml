pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Wallpapers: folder listing, cached thumbnails, apply through ~/.local/bin/setwall
// (setwall writes hyprpaper.conf, switches hyprpaper live and runs `wal -i`; Theme then recolours itself).
Singleton {
    id: root

    readonly property string home: Quickshell.env("HOME")
    property string rootDir: home + "/pix/wallpapers"
    property string folder: "dusky-dark"             // same default as setwall's WALL_DIR
    readonly property string setwall: home + "/.local/bin/setwall"
    readonly property string thumbDir: home + "/.cache/aurora/thumbs"

    property var folders: []                         // subfolder names; "" = everything under rootDir
    property var files: []                           // absolute paths of the current folder
    property var ready: ({})                         // md5(path) -> true once its thumbnail exists
    property string current: ""                      // wallpaper hyprpaper is showing
    property bool loading: false

    function dirOf(name) { return name === "" ? rootDir : rootDir + "/" + name }
    function thumbOf(path) { return thumbDir + "/" + Qt.md5(path) + ".jpg" }

    function refresh() {
        dirsProc.running = true
        listFolder(folder)
    }
    function listFolder(name) {
        folder = name
        thumbProc.running = false
        listProc.running = false
        loading = true
        listProc.command = ["find", dirOf(name), "-type", "f", "-not", "-path", "*/.*",
                            "-regextype", "posix-extended", "-iregex", ".*\\.(png|jpe?g|webp)"]
        listProc.running = true
    }
    function apply(path) {
        if (!path) return
        current = path
        Quickshell.execDetached([setwall, "-p", path])
    }
    // random from the folder shown last; before the first listing let setwall pick (its own WALL_DIR)
    function random() {
        if (files.length) apply(files[Math.floor(Math.random() * files.length)])
        else Quickshell.execDetached([setwall])
    }

    Process {
        id: dirsProc
        command: ["find", root.rootDir, "-mindepth", "1", "-maxdepth", "1", "-type", "d", "-not", "-name", ".*"]
        stdout: StdioCollector {
            onStreamFinished: {
                var out = [], l = text.split("\n")
                for (var i = 0; i < l.length; i++) {
                    var s = l[i].trim()
                    if (s !== "") out.push(s.substring(s.lastIndexOf("/") + 1))
                }
                out.sort()
                root.folders = out
            }
        }
    }

    Process {
        id: listProc
        stdout: StdioCollector {
            onStreamFinished: {
                var out = [], l = text.split("\n")
                for (var i = 0; i < l.length; i++) if (l[i] !== "") out.push(l[i])
                out.sort()
                root.files = out
                root.loading = false
                root.makeThumbs()
            }
        }
    }

    // ---- thumbnails ----
    // one background job per folder: 4 parallel `magick` runs, prints each hash when its thumb exists
    readonly property string thumbJob:
        'f="$1"; h=$(printf %s "$f" | md5sum | cut -c1-32); t="$0/$h.jpg"; ' +
        'if [ ! -f "$t" ]; then ' +
        '  magick "$f[0]" -thumbnail 320x180^ -gravity center -extent 320x180 -quality 82 "$t.part.jpg" 2>/dev/null ' +
        '  && mv "$t.part.jpg" "$t"; ' +
        'fi; [ -f "$t" ] && echo "$h"'
    function makeThumbs() {
        if (!files.length) return
        thumbProc.command = ["sh", "-c",
            'j="$1"; d="$2"; shift 2; mkdir -p "$d"; printf "%s\\0" "$@" | xargs -0 -n1 -P4 sh -c "$j" "$d"',
            "sh", thumbJob, thumbDir].concat(files)
        thumbProc.running = true
    }
    property var pendingReady: ({})
    Timer {
        id: flush
        interval: 250
        onTriggered: {
            var r = root.ready
            for (var k in root.pendingReady) r[k] = true
            root.pendingReady = {}
            root.ready = r
            root.readyChanged()
        }
    }
    Process {
        id: thumbProc
        stdout: SplitParser {
            onRead: line => {
                root.pendingReady[line.trim()] = true
                if (!flush.running) flush.start()
            }
        }
    }

    // current wallpaper, straight from the config setwall writes
    FileView {
        path: root.home + "/.config/hypr/hyprpaper.conf"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            var m = text().match(/^\s*path\s*=\s*(.+)$/m)
            if (m) root.current = m[1].trim()
        }
    }
}
