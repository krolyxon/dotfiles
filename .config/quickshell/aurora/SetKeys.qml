import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

// Settings app > Keybinds: read-only, searchable list parsed from ~/.config/hypr/source/keybinds.lua
// (`hyprctl binds` only shows "__lua <n>" for Lua binds). Comments above binds become the groups.
ColumnLayout {
    id: page
    spacing: 8
    readonly property string file: Quickshell.env("HOME") + "/.config/hypr/source/keybinds.lua"
    property var binds: []            // [{group, keys, action}]
    property string query: ""

    // split the argument list of a call at top-level commas (strings and nested brackets respected)
    function splitArgs(s) {
        var out = [], depth = 0, q = "", cur = ""
        for (var i = 0; i < s.length; i++) {
            var c = s[i]
            if (q !== "") {
                cur += c
                if (c === q && s[i - 1] !== "\\") q = ""
                continue
            }
            if (c === '"' || c === "'") { q = c; cur += c; continue }
            if (c === "(" || c === "{" || c === "[") depth++
            if (c === ")" || c === "}" || c === "]") depth--
            if (c === "," && depth === 0) { out.push(cur.trim()); cur = ""; continue }
            cur += c
        }
        if (cur.trim() !== "") out.push(cur.trim())
        return out
    }
    function keys(expr) {
        if (/\.\.\s*n\b/.test(expr)) return "SUPER + 1..0"            // the workspace loop
        var k = expr.replace(/mainMod/g, '"SUPER"').replace(/\.\./g, "").replace(/["']/g, "")
        return k.split("+").map(function (x) { x = x.trim(); return x.length === 1 ? x.toUpperCase() : x }).filter(function (x) { return x !== "" })
            .join(" + ").replace(/mouse:272/, "left-drag").replace(/mouse:273/, "right-drag")
            .replace(/mouse:274/, "middle-drag").replace(/mouse_down/, "scroll down").replace(/mouse_up/, "scroll up")
    }
    function action(expr, opts) {
        var d = /desc(?:ription)?\s*=\s*"([^"]*)"/.exec(opts || "")
        if (d) return d[1]
        var e = /exec_cmd\(([\s\S]*)\)\s*$/.exec(expr)
        if (e) return e[1].replace(/\\"/g, "\u0001").replace(/"/g, "").replace(/\u0001/g, '"')   // terminal .. " -e x" -> terminal -e x
            .replace(/\s*\.\.\s*/g, " ").trim()
        if (/^function/.test(expr)) return "lua function"
        return expr.replace(/^hl\.dsp\./, "").replace(/["{}]/g, "").replace(/\s*=\s*/g, "=")
            .replace(/\(\s*/g, " ").replace(/\s*\)/g, "").replace(/\s+/g, " ").trim()
    }
    function parse(t) {
        var lines = t.split("\n"), out = [], group = "", buf = "", depth = 0
        for (var i = 0; i < lines.length; i++) {
            var l = lines[i], tr = l.trim()
            if (buf === "") {
                var cm = /^--+\s*(.*?)\s*-*$/.exec(tr)
                if (cm && cm[1] !== "" && !/^bind\s*=/.test(cm[1]) && cm[1].indexOf("http") < 0 && !/^-+$/.test(cm[1])) group = cm[1].replace(/^-+\s*/, "")
                if (tr.indexOf("hl.bind(") !== 0) continue
            }
            buf += l + "\n"
            depth += (l.match(/\(/g) || []).length - (l.match(/\)/g) || []).length
            if (depth > 0) continue
            var inner = buf.slice(buf.indexOf("hl.bind(") + 8, buf.lastIndexOf(")"))
            var a = splitArgs(inner)
            if (a.length >= 2) out.push({ group: group, keys: keys(a[0]), action: action(a[1], a[2]) })
            buf = ""
            depth = 0
        }
        binds = out
    }

    readonly property var shown: {
        var q = query.toLowerCase(), out = [], last = null
        for (var i = 0; i < binds.length; i++) {
            var b = binds[i]
            if (q !== "" && (b.keys + " " + b.action + " " + b.group).toLowerCase().indexOf(q) < 0) continue
            if (b.group !== last) { out.push({ header: b.group }); last = b.group }   // group header row
            out.push(b)
        }
        return out
    }

    FileView {
        path: page.file
        watchChanges: true
        onFileChanged: reload()
        onLoaded: page.parse(text())
    }

    Field {
        id: search
        label: Theme.iSearch + "  filter"
        placeholder: "key, command or group"
        onEdited: v => page.query = v
    }

    ListView {
        Layout.fillWidth: true
        Layout.fillHeight: true
        clip: true
        spacing: 2
        model: page.shown
        boundsBehavior: Flickable.StopAtBounds
        delegate: RowLayout {
            required property var modelData
            readonly property bool isHeader: modelData.header !== undefined
            width: ListView.view.width
            spacing: 10
            SectionLabel {
                visible: parent.isHeader
                Layout.topMargin: 6
                text: parent.isHeader ? parent.modelData.header : ""
            }
            Rectangle {
                visible: !parent.isHeader
                Layout.preferredWidth: 220
                implicitHeight: 24
                color: Theme.surface
                border.width: 1
                border.color: Theme.line
                Text {
                    anchors.fill: parent
                    anchors.leftMargin: 6
                    verticalAlignment: Text.AlignVCenter
                    text: modelData.keys || ""
                    color: Theme.accent
                    elide: Text.ElideRight
                    font.family: Theme.font
                    font.pixelSize: Theme.fontSize - 1
                    font.bold: true
                }
            }
            Text {
                visible: !parent.isHeader
                Layout.fillWidth: true
                text: modelData.action || ""
                color: Theme.fg
                elide: Text.ElideRight
                font.family: Theme.font
                font.pixelSize: Theme.fontSize - 1
            }
        }
    }
    Text {
        text: page.binds.length + " binds  ·  " + page.file.replace(Quickshell.env("HOME"), "~")
        color: Theme.dim
        font.family: Theme.font
        font.pixelSize: Theme.fontSize - 2
    }
}
