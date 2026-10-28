pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Wallpapers: folder listing, cached thumbnails, and applying them. aurora owns the wallpaper and draws it itself
// (Back.qml / WallView.qml, look = Settings.wallLook): apply() records the path in hyprpaper.conf (only as the record,
// hyprpaper isn't run any more) and runs matugen (all colours, terminal included; Theme then recolours itself). recolor() re-runs just matugen when the scheme/contrast setting changes.
// ~/.local/bin/setwall is only a CLI front-end for the IPC calls (wallrandom / wall / wallset).
Singleton {
    id: root

    readonly property string home: Quickshell.env("HOME")
    property string rootDir: home + "/pix/wallpapers"
    property string folder: Settings.wallFolder      // default dusky-dark
    readonly property string conf: home + "/.config/hypr/hyprpaper.conf"
    readonly property string thumbDir: home + "/.cache/aurora/thumbs"

    property var folders: []                         // subfolder names; "" = everything under rootDir
    property var files: []                           // absolute paths of the current folder
    property var ready: ({})                         // md5(path) -> true once its thumbnail exists
    property string current: ""                      // the wallpaper on screen
    property bool loading: false
    property bool pendingRandom: false               // random() asked before the folder was listed
    property bool checkedColours: false              // matugen output checked once at startup

    function dirOf(name) { return name === "" ? rootDir : rootDir + "/" + name }
    function thumbOf(path) { return thumbDir + "/" + Qt.md5(path) + ".jpg" }

    function refresh() {
        dirsProc.running = true
        listFolder(folder)
    }
    function listFolder(name) {
        folder = name
        Settings.wallFolder = name
        thumbProc.running = false
        listProc.running = false
        loading = true
        listProc.command = ["find", dirOf(name), "-type", "f", "-not", "-path", "*/.*",
                            "-regextype", "posix-extended", "-iregex", ".*\\.(png|jpe?g|webp)"]
        listProc.running = true
    }
    // hyprpaper.conf is the record of the current wallpaper (kept in hyprpaper's format, so it still works if
    // hyprpaper is ever started again)
    readonly property string applyJob:
        'p="$1"; c="$2"; ' +
        'printf "splash = false\\nwallpaper {\\n    monitor =\\n    path = %s\\n}\\n" "$p" > "$c"; ' +
        'matugen image "$p" -m dark -t "$3" --contrast="$4" --prefer saturation -q'
    function apply(path) {
        if (!path) return
        current = path
        Quickshell.execDetached(["sh", "-c", applyJob, "sh", path, conf, Settings.matuScheme, String(Settings.matuContrast)])
    }

    // matugen only. --prefer: v4 otherwise asks on stdin when the image has several source colours.
    // With "missing", only if there is no output yet (fresh install).
    readonly property string matuJob:
        '[ "$4" = missing ] && [ -f "$HOME/.cache/matugen/aurora.json" ] && exit 0; ' +
        'matugen image "$1" -m dark -t "$2" --contrast="$3" --prefer saturation -q'
    function recolor(onlyIfMissing) {
        if (!current) return
        Quickshell.execDetached(["sh", "-c", matuJob, "sh", current, Settings.matuScheme,
                                 String(Settings.matuContrast), onlyIfMissing ? "missing" : ""])
    }
    Timer { id: recolorLater; interval: 400; onTriggered: root.recolor(false) }
    Connections {
        target: Settings
        function onMatuSchemeChanged() { recolorLater.restart() }
        function onMatuContrastChanged() { recolorLater.restart() }
    }
    // random from the picker's folder (Settings.wallFolder), never the one already shown
    function random() {
        if (!files.length) {
            pendingRandom = true
            if (!loading) listFolder(folder)
            return
        }
        var pick = files.filter(f => f !== current)
        if (!pick.length) pick = files
        apply(pick[Math.floor(Math.random() * pick.length)])
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
                if (root.pendingRandom) { root.pendingRandom = false; if (out.length) root.random() }
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

    // current wallpaper, from its record in hyprpaper.conf. None yet (fresh install): pick a random one.
    FileView {
        path: root.conf
        watchChanges: true
        onFileChanged: reload()
        onLoadFailed: root.random()
        onLoaded: {
            var m = text().match(/^\s*path\s*=\s*(.+)$/m)
            if (m) root.current = m[1].trim()
            if (!root.checkedColours) { root.checkedColours = true; root.recolor(true) }
        }
    }
}
