pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

// Screenshots: open() freezes the focused monitor with grim (raw ppm in $XDG_RUNTIME_DIR: ~90 ms, png ~450) and ShotAim
// shows that frame under the viewfinder (region / window / screen / record, timer). fire(rect): without a timer vips crops
// the frozen frame (what you saw is what you get), with one grim takes the live screen after a countdown (ShotAim shows it;
// the timer is off again on every open: left on, it silently delayed every later shot). Every shot is
// copied; it's only a file in /tmp (tmpfs: gone on reboot, but there to paste a path) unless kept: Ctrl+S in the
// viewfinder or editor, or "save" on the card, puts it in ~/pix/ss. After a shot ShotAim flashes the area and shows a
// card, a click on it opens ShotEditor (`editing`).
// Record mode hands the area to Rec (wf-recorder). OCR is the separate `ocr` script (slurp + grim + tesseract).
// After glyph-rice (github.com/Nebelung-cloud/glyph-rice, GPL-3.0), shot/Shot.qml.
Singleton {
    id: root

    readonly property var modes: ["region", "window", "screen", "record"]
    readonly property var delays: [0, 3, 10]
    readonly property string dir: Quickshell.env("HOME") + "/pix/ss"      // kept shots
    readonly property string tmp: "/tmp"                                  // the rest
    readonly property string run: Quickshell.env("XDG_RUNTIME_DIR") || "/tmp"

    property bool aiming: false          // the viewfinder is up
    property bool snap: false            // hide it without the fade (the live screen is captured right after)
    property int mode: 0                 // index into modes
    property int delay: 0                // index into delays
    property var scr: null               // ShellScreen of the frozen monitor
    property var mon: null               // its HyprlandMonitor (x/y in layout coordinates)
    property string frozen: ""
    property var wins: []                // windows on its workspace, logical px relative to it: {x, y, w, h}, topmost first
    property point cursor                // the cursor when it froze, relative to the screen; -1 = unknown

    // the last shot (flash + card)
    property string last: ""             // its file
    readonly property bool kept: last !== "" && last.indexOf(dir + "/") === 0
    property string lastWhat: ""
    property string lastDims: ""
    property rect lastRect
    property bool lastRec: false
    signal fired()

    property string editing: ""          // file open in ShotEditor
    property int countdown: 0            // seconds left before a timed shot / recording
    property string countWhat: ""        // "shot" | "rec"

    // m: "region" | "window" | "screen" | "record" (anything else = region); wait: ms to let a panel/overlay leave first
    function open(m, wait) {
        if (aiming) { close(); return }          // Print again = cancel
        if (countdown > 0) { tick.stop(); countdown = 0; return }   // ... also a running countdown
        if (freeze.running) return
        var i = modes.indexOf(m)
        mode = i >= 0 && (i !== 3 || Rec.available) ? i : 0
        delay = 0
        if (wait > 0) { later.interval = wait; later.restart() }
        else start()
    }
    function close() { snap = false; aiming = false }
    function ocr(wait) { Quickshell.execDetached(["sh", "-c", 'sleep "$1"; exec ocr', "sh", String((wait || 0) / 1000)]) }
    function edit() { editing = editing !== "" ? "" : last }      // toggle: `shot edit` again discards
    function isTemp(f) { return f.indexOf(tmp + "/") === 0 }
    function tempPath() { return tmp + "/shot-" + Qt.formatDateTime(new Date(), "yyyy-MM-dd_HH-mm-ss") + ".png" }

    // file -> clipboard; keep = also into ~/pix/ss (same name). Becomes `last` (the card shows it). Used by the card's
    // save chip (keep()) and the editor; quiet = no "saved" notification (the card already says so)
    function done(file, keep, quiet) {
        doneProc.quiet = !!quiet
        doneProc.command = ["sh", "-c", 'f="$1"; if [ "$2" = 1 ]; then mkdir -p "$3" && cp -f "$f" "$3/${f##*/}" && f="$3/${f##*/}" || exit 1; fi\n'
            + 'wl-copy -t image/png < "$f" && printf %s "$f"', "sh", file, keep ? "1" : "0", dir]
        doneProc.running = true
    }
    function keep() { if (last !== "" && !kept) done(last, true, true) }
    Process {
        id: doneProc
        property bool quiet
        stdout: StdioCollector {
            onStreamFinished: {
                if (text === "") return
                root.last = text
                if (root.kept && !doneProc.quiet)
                    Quickshell.execDetached(["notify-send", "-a", "aurora", "-i", text, "screenshot saved", text])
            }
        }
        onExited: code => {
            if (code !== 0) Quickshell.execDetached(["notify-send", "-a", "aurora", "-u", "critical", "screenshot", "couldn't copy / save it"])
        }
    }

    Timer { id: later; onTriggered: root.start() }

    function start() {
        var m = Hyprland.focusedMonitor, l = Quickshell.screens, s = l[0]
        for (var i = 0; i < l.length; i++) if (m && l[i].name === m.name) s = l[i]
        scr = s
        mon = m
        Hyprland.refreshToplevels()      // async: read back once grim is done
        freeze.next = run + "/aurora-frozen-" + Date.now() + ".ppm"
        // + where the cursor is (layout coordinates), so the crosshair, loupe and window mode work before the mouse moves
        freeze.command = ["sh", "-c", 'rm -f "$3"/aurora-frozen-*.ppm; grim -t ppm -o "$1" "$2" && echo ok && hyprctl cursorpos',
                          "sh", s.name, freeze.next, run]
        freeze.running = true
    }
    Process {
        id: freeze
        property string next
        stdout: StdioCollector {
            onStreamFinished: {
                var l = text.trim().split("\n")
                if (l[0] !== "ok") return
                var c = (l[1] || "").split(",")
                root.cursor = c.length === 2 ? Qt.point(parseFloat(c[0]) - (root.mon ? root.mon.x : 0), parseFloat(c[1]) - (root.mon ? root.mon.y : 0))
                                             : Qt.point(-1, -1)
                root.frozen = freeze.next     // only now: the file is complete
                root.wins = root.windows()
                root.snap = false
                root.aiming = true
            }
        }
    }

    // windows of the frozen monitor's workspace (+ its open special workspace on top), floating ones above tiled
    function windows() {
        var m = mon, ipc = m ? m.lastIpcObject : null
        var ws = m && m.activeWorkspace ? m.activeWorkspace.id : -1
        var sp = ipc && ipc.specialWorkspace ? ipc.specialWorkspace.id : 0
        var l = Hyprland.toplevels.values, out = []
        for (var i = 0; i < l.length; i++) {
            var o = l[i].lastIpcObject, w = l[i].workspace
            if (!w || !o || !o.size || !o.at || (w.id !== ws && (sp === 0 || w.id !== sp))) continue
            out.push({ x: o.at[0] - m.x, y: o.at[1] - m.y, w: o.size[0], h: o.size[1],
                       z: (w.id === sp ? 2 : 0) + (o.floating ? 1 : 0) })
        }
        out.sort(function (a, b) { return b.z - a.z })
        return out
    }

    // r: logical rect relative to the screen; fs: the frozen frame's size in pixels; keep: into ~/pix/ss, not /tmp
    function fire(r, fs, keep) {
        var W = scr.width, H = scr.height, k = fs.width / Math.max(1, W)
        var x0 = Math.max(0, r.x), y0 = Math.max(0, r.y)
        var x1 = Math.min(W, r.x + r.width), y1 = Math.min(H, r.y + r.height)
        if (x1 - x0 <= 2 || y1 - y0 <= 2) { x0 = 0; y0 = 0; x1 = W; y1 = H }
        r = Qt.rect(x0, y0, x1 - x0, y1 - y0)
        var full = r.width >= W && r.height >= H
        var w = Math.round(r.width), h = Math.round(r.height)
        var gx = Math.round((mon ? mon.x : 0) + r.x), gy = Math.round((mon ? mon.y : 0) + r.y)
        lastRect = r
        lastRec = mode === 3
        lastWhat = modes[mode] + " · " + Theme.hh(new Date()) + ":" + Qt.formatTime(new Date(), "mm")
        // the viewfinder goes at once, no fade: recordings and timed shots capture the live screen
        snap = true
        aiming = false

        var live = delays[delay] > 0
        if (lastRec) {
            lastDims = w + "×" + h
            var g = full ? "" : gx + "," + gy + " " + w + "x" + h
            after(live, "rec", function () { Rec.begin(g); root.fired() })
            return
        }
        // vips (unlike magick) fails on a crop a pixel past the frame: fractional scales, so clamp in pixels
        var cx = Math.min(fs.width - 1, Math.round(r.x * k)), cy = Math.min(fs.height - 1, Math.round(r.y * k))
        var cw = Math.max(1, Math.min(Math.round(r.width * k), fs.width - cx))
        var ch = Math.max(1, Math.min(Math.round(r.height * k), fs.height - cy))
        lastDims = cw + "×" + ch
        take.command = ["sh", "-c", 'mkdir -p "$5"; f="$5/shot-$(date +%F_%H-%M-%S).png"\n'
            + 'if [ "$1" = 0 ]; then vips crop "$4" "$f[compression=1]" $2 2>/dev/null; else grim -g "$3" "$f"; fi'
            + ' && wl-copy -t image/png < "$f" && printf %s "$f"',
            "sh", live ? "1" : "0", cx + " " + cy + " " + cw + " " + ch, gx + "," + gy + " " + w + "x" + h, frozen, keep ? dir : tmp]
        after(live, "shot", function () { take.running = true })
    }

    // now, or after the timer's countdown; the countdown pill gets 150ms to leave the screen before the live capture
    property var pending: null
    function after(timed, what, fn) {
        if (!timed) { fn(); return }
        pending = fn
        countWhat = what
        countdown = delays[delay]
        tick.restart()
    }
    Timer {
        id: tick
        interval: 1000
        repeat: true
        onTriggered: {
            root.countdown--
            if (root.countdown > 0) return
            stop()
            go.restart()
        }
    }
    Timer { id: go; interval: 150; onTriggered: if (root.pending) root.pending() }
    Process {
        id: take
        stdout: StdioCollector {
            onStreamFinished: {
                if (text === "") return
                root.last = text
                root.fired()
            }
        }
        onExited: code => {
            if (code !== 0) Quickshell.execDetached(["notify-send", "-a", "aurora", "-u", "critical", "screenshot failed",
                                                     "grim / vips exited with " + code])
        }
    }

}
