import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland

// App / command runner (replaced fuzzel on SUPER+R). One fuzzy list of desktop apps (+ their actions),
// aurora commands and every executable on $PATH, ranked by match and launch count.
// `=expr` calculator (Enter copies), `>cmd` runs a shell command. Ctrl+Enter runs in the terminal.
// dmenu mode (`aurora-run -d`, `dmenu` IPC): plain list from the script's stdin, the choice goes back over a fifo.
PanelWindow {
    id: win
    property bool opened: false
    property var shell                 // shell.qml root: toggleOverlay / openTab / barShown
    signal closeRequested()
    signal openRequested()             // a dmenu request is loaded and wants the window

    readonly property int rowH: 36
    readonly property int rows: 10
    readonly property int maxShown: 60
    readonly property string home: Quickshell.env("HOME")

    // ---- dmenu mode ----
    property string mode: "run"        // run | dmenu
    property var dmItems: []           // [{kind:"dm", name, low, i}]
    property string dmPrompt: ""
    property string dmPlaceholder: ""
    property int dmLines: -1           // -1 default, 0 = input only (no list)
    property bool dmPassword: false
    property bool dmIndex: false
    property string dmFifo: ""         // pending request's reply fifo, "" when none
    readonly property bool dmenu: mode === "dmenu"
    readonly property int rowsShown: !dmenu ? rows
        : dmLines === 0 ? 0 : Math.min(dmLines > 0 ? dmLines : rows, 15, Math.max(1, dmItems.length))

    // dir holds `opts` (key=value lines) and `items` (stdin of the script), see ~/.local/bin/aurora-run
    function startDmenu(dir) {
        if (dmFifo !== "") reply(false, "")   // a newer request replaces a pending one
        loadProc.dir = dir
        loadProc.command = ["sh", "-c", 'cat "$1/opts"; printf "\\036\\n"; [ -f "$1/items" ] && cat "$1/items"', "sh", dir]
        loadProc.running = true
    }
    Process {
        id: loadProc
        property string dir
        stdout: StdioCollector {
            onStreamFinished: {
                var sep = text.indexOf("\x1e\n")
                if (sep < 0) return
                var o = {}, ol = text.substring(0, sep).split("\n")
                for (var i = 0; i < ol.length; i++) {
                    var eq = ol[i].indexOf("=")
                    if (eq > 0) o[ol[i].substring(0, eq)] = ol[i].substring(eq + 1)
                }
                var items = [], l = text.substring(sep + 2).split("\n")
                for (var j = 0; j < l.length; j++)
                    if (l[j] !== "") items.push({ kind: "dm", key: "", name: l[j], low: l[j].toLowerCase(), i: j,
                                                  sub: "", icon: "", glyph: "", tag: "" })
                win.dmPrompt = o.prompt || ""
                win.dmPlaceholder = o.placeholder || ""
                win.dmLines = o.lines !== undefined && o.lines !== "" ? parseInt(o.lines) : -1
                win.dmPassword = o.password === "1"
                win.dmIndex = o.index === "1"
                win.dmItems = items
                win.dmFifo = loadProc.dir + "/reply"
                win.mode = "dmenu"
                filter.text = ""
                win.current = 0
                win.openRequested()
                filter.forceActiveFocus()
            }
        }
    }
    // "<0|1>\n<value>\0" to the fifo through stdin, so a password never shows up in a process's argv
    function reply(ok, value) {
        replyProc.payload = (ok ? "0" : "1") + "\n" + value + "\0"
        replyProc.command = ["sh", "-c", 'cat > "$1"', "sh", dmFifo]
        replyProc.stdinEnabled = true
        replyProc.running = true
        dmFifo = ""
    }
    Process {
        id: replyProc
        property string payload
        onStarted: { write(payload); payload = ""; stdinEnabled = false }
    }
    function endDmenu() {
        mode = "run"
        dmItems = []
        dmPassword = false
        filter.text = ""
    }

    visible: opened
    implicitWidth: dmenu ? 640 : 560
    implicitHeight: 24 + 36 + rowsShown * rowH + 22
    exclusiveZone: 0
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "aurora-runner"
    WlrLayershell.keyboardFocus: opened ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    HyprlandFocusGrab {
        windows: [win]
        active: win.opened
        onCleared: win.closeRequested()
    }

    property int current: 0
    property string armed: ""
    Timer { id: disarm; interval: 3000; onTriggered: win.armed = "" }

    onOpenedChanged: {
        if (!opened) {
            // closed without a choice (esc, outside click, another overlay): the script gets "cancelled"
            if (dmFifo !== "") reply(false, "")
            if (dmenu) endDmenu()
            return
        }
        armed = ""
        filter.forceActiveFocus()
        if (dmenu) return              // startDmenu already reset the input
        filter.text = ""
        current = 0
        if (Date.now() - binsAt > 60000) binProc.running = true
    }

    // ---- sources ----
    function basename(p) { p = String(p); return p.substring(p.lastIndexOf("/") + 1) }

    // desktop entries + their actions ("Librewolf: New Private Window")
    property var apps: []
    function loadApps() {
        var out = [], l = DesktopEntries.applications.values
        for (var i = 0; i < l.length; i++) {
            var e = l[i]
            if (e.noDisplay) continue
            var ic = e.icon ? Quickshell.iconPath(e.icon, true) : ""
            var bin = e.command && e.command.length ? basename(e.command[0]) : ""
            out.push({ kind: "app", key: "app:" + e.id, name: e.name, sub: e.genericName || e.comment || "",
                       icon: ic, glyph: Theme.iApp, tag: "app", entry: e, action: null, bin: bin,
                       hay: [e.genericName || "", (e.keywords || []).join(" "), bin] })
            var acts = e.actions || []
            for (var j = 0; j < acts.length; j++)
                out.push({ kind: "act", key: "act:" + e.id + ":" + acts[j].id, name: e.name + ": " + acts[j].name, sub: "",
                           icon: ic, glyph: Theme.iApp, tag: "app", entry: e, action: acts[j], bin: "", hay: [] })
        }
        apps = out
    }
    Component.onCompleted: loadApps()
    Connections {
        target: DesktopEntries
        function onApplicationsChanged() { win.loadApps() }
    }

    // executables on $PATH (first one wins, like the shell). Apps whose binary is already listed are skipped.
    property var bins: []
    property double binsAt: 0
    Process {
        id: binProc
        command: ["sh", "-c", 'set -f; IFS=:; for d in $PATH; do [ -d "$d" ] && find -L "$d" -maxdepth 1 -type f -executable -printf "%f\\t%p\\n" 2>/dev/null; done']
        stdout: StdioCollector {
            onStreamFinished: {
                var seen = {}, out = [], l = text.split("\n")
                for (var i = 0; i < l.length; i++) {
                    var t = l[i].indexOf("\t")
                    if (t <= 0) continue
                    var n = l[i].substring(0, t)
                    if (seen[n]) continue
                    seen[n] = true
                    out.push({ kind: "bin", key: "bin:" + n, name: n, sub: l[i].substring(t + 1),
                               icon: "", glyph: Theme.iConsole, tag: "bin", hay: [] })
                }
                win.bins = out
                win.binsAt = Date.now()
            }
        }
    }

    // aurora's own actions. Session ones come from Session (same confirm rules as the power menu).
    readonly property var commands: {
        var c = [
            { id: "panel",    glyph: Theme.iHome,      name: "control panel" },
            { id: "audio",    glyph: Theme.iVolHigh,   name: "audio settings" },
            { id: "net",      glyph: Theme.iWifi,      name: "network settings" },
            { id: "bt",       glyph: Theme.iBt,        name: "bluetooth settings" },
            { id: "sys",      glyph: Theme.iChip,      name: "system info" },
            { id: "notif",    glyph: Theme.iBell,      name: "notifications" },
            { id: "settings", glyph: Theme.iCog,       name: "aurora settings" },
            { id: "wall",     glyph: Theme.iImage,     name: "wallpaper picker" },
            { id: "wallrnd",  glyph: Theme.iShuffle,   name: "random wallpaper" },
            { id: "clip",     glyph: Theme.iClipboard, name: "clipboard history" },
            { id: "overview", glyph: Theme.iWindow,    name: "window overview" },
            { id: "cal",      glyph: Theme.iCal,       name: "calendar" },
            { id: "power",    glyph: Theme.iPower,     name: "power menu" },
            { id: "caffeine", glyph: Theme.iCoffee,    name: "toggle caffeine" },
            { id: "dnd",      glyph: Theme.iBellOff,   name: "toggle do not disturb" },
            { id: "bar",      glyph: Theme.iMonitor,   name: "toggle bar" },
            { id: "picker",   glyph: Theme.iPicker,    name: "colour picker" },
            { id: "shot",     glyph: Theme.iCrop,      name: "screenshot region" },
            { id: "ocr",      glyph: Theme.iCrop,      name: "screenshot ocr" }
        ]
        if (Rec.available) c.push({ id: "rec", glyph: Theme.iRec, name: Rec.busy ? "stop recording" : "record screen" })
        var out = []
        for (var i = 0; i < c.length; i++)
            out.push({ kind: "aurora", key: "aur:" + c[i].id, id: c[i].id, name: c[i].name, sub: "", icon: "",
                       glyph: c[i].glyph, tag: "aurora", confirm: false, hay: [] })
        var s = Session.actions
        for (var j = 0; j < s.length; j++)
            out.push({ kind: "session", key: "ses:" + s[j].id, id: s[j].id, name: s[j].label, sub: "session", icon: "",
                       glyph: s[j].icon, tag: "aurora", confirm: s[j].confirm, hay: [] })
        return out
    }

    // ---- frecency: launch counts in ~/.cache/aurora/runner.json ----
    property var counts: ({})
    FileView {
        id: store
        path: win.home + "/.cache/aurora/runner.json"
        printErrors: false
        onLoaded: { try { win.counts = JSON.parse(text()) } catch (e) { win.counts = {} } }
    }
    function bump(key) {
        var c = {}
        for (var k in counts) c[k] = counts[k]
        c[key] = (c[key] || 0) + 1
        counts = c
        store.setText(JSON.stringify(c))
    }

    // ---- calculator ----
    readonly property var mathFns: ["sqrt", "cbrt", "abs", "sin", "cos", "tan", "asin", "acos", "atan",
                                    "log", "log2", "log10", "exp", "floor", "ceil", "round", "min", "max", "pow"]
    function calc(expr) {
        if (!/^[0-9a-z\s.+\-*\/%^(),]+$/i.test(expr) || !/\d|pi/i.test(expr)) return ""
        var bad = false
        var js = expr.replace(/\^/g, "**").replace(/[a-z][a-z0-9]*/gi, function (w) {
            var l = w.toLowerCase()
            if (l === "pi") return "Math.PI"
            if (l === "e") return "Math.E"
            if (l === "ln") return "Math.log"
            if (win.mathFns.indexOf(l) >= 0) return "Math." + l
            bad = true
            return w
        })
        if (bad) return ""
        try {
            var r = (new Function("return (" + js + ")"))()
            if (typeof r !== "number" || !isFinite(r)) return ""
            return String(Number(r.toPrecision(12)))
        } catch (e) { return "" }
    }

    // ---- ranking ----
    function rank(it, q) {
        var s = Fuzzy.score(it.name, q)
        for (var i = 0; i < it.hay.length; i++)
            if (it.hay[i] !== "") s = Math.max(s, Fuzzy.score(it.hay[i], q) * 0.6)
        if (s <= 0) return 0
        var w = it.kind === "app" ? 1 : it.kind === "bin" ? 0.6 : 0.85
        return s * w + 60 * Math.log(1 + (counts[it.key] || 0))
    }
    readonly property var shown: {
        var raw = filter.text, q = raw.toLowerCase().trim(), res = []
        if (dmenu) {
            if (dmLines === 0) return res
            var cap = 1000, dl = dmItems, di
            if (q === "") return dl.length > cap ? dl.slice(0, cap) : dl
            var hits = []
            for (di = 0; di < dl.length; di++) {
                var dsc = Fuzzy.scoreLow(dl[di].low, q)
                if (dsc > 0) hits.push({ it: dl[di], sc: dsc })
            }
            hits.sort(function (x, y) { return y.sc - x.sc || x.it.i - y.it.i })
            for (di = 0; di < hits.length && di < cap; di++) res.push(hits[di].it)
            return res
        }
        if (q.charAt(0) === ">") {
            var cmd = raw.trim().substring(1).trim()
            if (cmd !== "") res.push({ kind: "sh", key: "", name: cmd, sub: "run in sh", icon: "", glyph: Theme.iShell, tag: "sh" })
            return res
        }
        if (q.charAt(0) === "=") {
            var r = calc(q.substring(1))
            res.push({ kind: "calc", key: "", name: r !== "" ? r : "...", sub: q.substring(1).trim(), icon: "",
                       glyph: Theme.iCalc, tag: "=", value: r })
            return res
        }
        if (/[\d)]\s*[+\-*\/%^]\s*[\d(.]/.test(q)) {
            var v = calc(q)
            if (v !== "") res.push({ kind: "calc", key: "", name: v, sub: q, icon: "", glyph: Theme.iCalc, tag: "=", value: v })
        }

        var all = [], i
        var appBins = {}
        for (i = 0; i < apps.length; i++) { all.push(apps[i]); if (apps[i].bin) appBins[apps[i].bin] = true }
        for (i = 0; i < commands.length; i++) all.push(commands[i])
        var scored = []
        if (q === "") {
            // most used first, then apps A-Z; no actions / bins / commands unless used before
            for (i = 0; i < bins.length; i++) if (counts[bins[i].key]) all.push(bins[i])
            for (i = 0; i < all.length; i++) {
                var n = counts[all[i].key] || 0
                if (n > 0 || all[i].kind === "app") scored.push({ it: all[i], sc: n })
            }
            scored.sort(function (x, y) { return y.sc - x.sc || x.it.name.localeCompare(y.it.name) })
        } else {
            for (i = 0; i < bins.length; i++) if (!appBins[bins[i].name]) all.push(bins[i])
            for (i = 0; i < all.length; i++) {
                var sc = rank(all[i], q)
                if (sc > 0) scored.push({ it: all[i], sc: sc })
            }
            scored.sort(function (x, y) { return y.sc - x.sc || x.it.name.length - y.it.name.length })
        }
        for (i = 0; i < scored.length && res.length < maxShown; i++) res.push(scored[i].it)
        // nothing matched: offer to run the text as a command, like fuzzel's execute-input
        if (res.length === 0 && q !== "")
            res.push({ kind: "sh", key: "", name: raw.trim(), sub: "run in sh", icon: "", glyph: Theme.iShell, tag: "sh" })
        return res
    }

    // ---- launching ----
    function exec(cmd, term) {
        Quickshell.execDetached({ command: term ? ["foot", "-e"].concat(cmd) : cmd, workingDirectory: home })
    }
    function trigger(i, term) {
        if (dmenu) {
            // like fuzzel: the selected line, or the typed text when nothing matches / Ctrl+Enter
            var sel = term ? null : shown[i]
            if (dmIndex) reply(true, sel ? String(sel.i) : "-1")
            else reply(true, sel ? sel.name : filter.text)
            closeRequested()
            return
        }
        var it = shown[i]
        if (!it) return
        current = i
        if (it.confirm && armed !== it.key) { armed = it.key; disarm.restart(); return }
        armed = ""
        if (it.key !== "") bump(it.key)
        closeRequested()
        switch (it.kind) {
        case "app":
            if (term || it.entry.runInTerminal) exec(it.entry.command, true)
            else it.entry.execute()
            break
        case "act":  it.action.execute(); break
        case "bin":  exec([it.name], term); break
        case "sh":   exec(["sh", "-c", it.name], term); break
        case "calc": if (it.value !== "") Quickshell.execDetached(["wl-copy", "--", it.value]); break
        case "session": Session.run(it.id); break
        case "aurora":  command(it.id); break
        }
    }
    function command(id) {
        switch (id) {
        case "panel":    shell.openTab("home"); break
        case "audio": case "net": case "bt": case "sys": case "notif": case "settings":
            shell.openTab(id); break
        case "wall": case "clip": case "overview": case "cal": case "power":
            shell.toggleOverlay(id); break
        case "wallrnd":  Wall.random(); break
        case "caffeine": Toggles.caffeine = !Toggles.caffeine; break
        case "dnd":      Notifs.dnd = !Notifs.dnd; break
        case "bar":      shell.barShown = !shell.barShown; break
        case "picker":   Toggles.pickColour(); break
        case "shot":     Shot.take("region"); break
        case "ocr":      Shot.take("ocr"); break
        case "rec":      Rec.toggle("screen"); break
        }
    }

    // ---- UI ----
    Rectangle {
        anchors.fill: parent
        color: Theme.bgA
        border.width: 2
        border.color: Theme.accent

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 2

            Rectangle {
                Layout.fillWidth: true
                Layout.bottomMargin: 6
                implicitHeight: 30
                color: Theme.surface
                border.width: 1
                border.color: filter.activeFocus ? Theme.accent : Theme.line
                Text {
                    id: promptText
                    anchors.left: parent.left
                    anchors.leftMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    text: win.dmenu && win.dmPrompt !== "" ? win.dmPrompt : (win.dmPassword ? Theme.iLock : Theme.iSearch)
                    color: win.dmenu && win.dmPrompt !== "" ? Theme.accent : Theme.dim
                    font.family: Theme.font
                    font.pixelSize: Theme.fontSize
                }
                Text {
                    anchors.left: filter.left
                    anchors.verticalCenter: parent.verticalCenter
                    visible: filter.text === "" && win.dmenu && win.dmPlaceholder !== ""
                    text: win.dmPlaceholder
                    color: Theme.dim
                    font.family: Theme.font
                    font.pixelSize: Theme.fontSize
                }
                TextInput {
                    id: filter
                    anchors.fill: parent
                    anchors.leftMargin: Math.max(32, promptText.implicitWidth + 20)
                    anchors.rightMargin: 10
                    verticalAlignment: TextInput.AlignVCenter
                    echoMode: win.dmPassword ? TextInput.Password : TextInput.Normal
                    passwordCharacter: "*"
                    color: Theme.fg
                    selectionColor: Theme.accent
                    selectedTextColor: Theme.bg
                    font.family: Theme.font
                    font.pixelSize: Theme.fontSize
                    clip: true
                    onTextChanged: { win.current = 0; win.armed = "" }
                    Keys.onEscapePressed: win.closeRequested()
                    Keys.onReturnPressed: event => win.trigger(win.current, event.modifiers & Qt.ControlModifier)
                    Keys.onEnterPressed: event => win.trigger(win.current, event.modifiers & Qt.ControlModifier)
                    Keys.onPressed: event => {
                        var n = win.shown.length
                        if (!n) return
                        var step = 0
                        if (event.key === Qt.Key_Down || event.key === Qt.Key_Tab) step = 1
                        else if (event.key === Qt.Key_Up || event.key === Qt.Key_Backtab) step = -1
                        else if (event.key === Qt.Key_PageDown) step = Math.max(2, win.rowsShown)
                        else if (event.key === Qt.Key_PageUp) step = -Math.max(2, win.rowsShown)
                        else if ((event.modifiers & Qt.ControlModifier) && (event.key === Qt.Key_N || event.key === Qt.Key_J)) step = 1
                        else if ((event.modifiers & Qt.ControlModifier) && (event.key === Qt.Key_P || event.key === Qt.Key_K)) step = -1
                        if (step === 0) return
                        if (Math.abs(step) === 1) win.current = (win.current + step + n) % n
                        else win.current = Math.max(0, Math.min(n - 1, win.current + step))
                        win.armed = ""
                        event.accepted = true
                    }
                }
            }

            ListView {
                id: list
                Layout.fillWidth: true
                Layout.fillHeight: true
                visible: win.rowsShown > 0
                clip: true
                spacing: 0
                boundsBehavior: Flickable.StopAtBounds
                model: win.shown
                currentIndex: win.current
                highlightFollowsCurrentItem: false
                onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)
                delegate: Rectangle {
                    id: row
                    required property var modelData
                    required property int index
                    readonly property bool selected: win.current === index
                    readonly property bool isArmed: win.armed !== "" && win.armed === modelData.key
                    width: list.width
                    height: win.rowH
                    color: isArmed ? Theme.err : (selected ? Theme.surfaceHi : (rm.containsMouse ? Theme.surface : "transparent"))
                    border.width: selected ? 1 : 0
                    border.color: isArmed ? Theme.err : Theme.accent

                    Rectangle {   // selection marker, like ClipWindow
                        visible: row.selected
                        width: 2
                        height: parent.height
                        color: row.isArmed ? Theme.bg : Theme.accent
                    }
                    Item {
                        id: icoBox
                        anchors.left: parent.left
                        anchors.leftMargin: row.modelData.kind === "dm" ? 2 : 10
                        anchors.verticalCenter: parent.verticalCenter
                        visible: row.modelData.kind !== "dm"
                        width: visible ? 24 : 0
                        height: 24
                        Image {
                            id: img
                            anchors.fill: parent
                            visible: row.modelData.icon !== "" && status === Image.Ready
                            source: row.modelData.icon
                            sourceSize.width: 48
                            sourceSize.height: 48
                            asynchronous: true
                            smooth: true
                        }
                        Text {
                            anchors.centerIn: parent
                            visible: !img.visible
                            text: row.modelData.glyph
                            color: row.isArmed ? Theme.bg : Theme.accent
                            font.family: Theme.font
                            font.pixelSize: Theme.fontSize + 4
                        }
                    }
                    Text {
                        id: tag
                        anchors.right: parent.right
                        anchors.rightMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        text: row.isArmed ? "sure?" : row.modelData.tag
                        color: row.isArmed ? Theme.bg : Theme.dim
                        font.family: Theme.font
                        font.pixelSize: Theme.fontSize - 2
                    }
                    Text {
                        id: nameText
                        anchors.left: icoBox.right
                        anchors.leftMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        width: Math.min(implicitWidth, tag.x - x - 12)
                        elide: Text.ElideRight
                        text: row.modelData.name
                        color: row.isArmed ? Theme.bg : Theme.fg
                        font.family: Theme.font
                        font.pixelSize: Theme.fontSize
                        font.bold: row.modelData.kind === "calc"
                    }
                    Text {
                        anchors.left: nameText.right
                        anchors.leftMargin: 10
                        anchors.right: tag.left
                        anchors.rightMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        elide: Text.ElideRight
                        text: row.modelData.sub
                        color: row.isArmed ? Theme.bg : Theme.dim
                        font.family: Theme.font
                        font.pixelSize: Theme.fontSize - 2
                    }
                    MouseArea {
                        id: rm
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: if (win.current !== row.index) { win.current = row.index; win.armed = "" }
                        onClicked: win.trigger(row.index, false)
                    }
                }
            }

            Text {
                Layout.fillWidth: true
                Layout.topMargin: 6
                text: !win.dmenu ? (win.shown.length ? "enter run   ctrl+enter terminal   =calc   >cmd   esc close" : "no match")
                    : win.rowsShown === 0 ? "enter ok   esc cancel"
                    : win.shown.length ? "enter select   ctrl+enter typed text   esc cancel" : "no match   enter typed text   esc cancel"
                color: win.shown.length || win.dmenu ? Theme.dim : Theme.err
                font.family: Theme.font
                font.pixelSize: Theme.fontSize - 2
            }
        }
    }
}
