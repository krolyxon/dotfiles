pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// The settings app's sections and its search index. Like Android indexes each preference XML, the rows are parsed out
// of the page files themselves: SectionLabel (a group) and Switch / Knob / Choice / Field / Timeout with a literal
// `label:`, plus their `hint:`, `keywords:` (synonyms, read only here) and a Choice's option labels. IconBtn only with
// `keywords:` (opt-in). Non-literal labels aren't indexed. `extras` covers rows without a label (wi-fi, bluetooth power).
// Editing a page hot-reloads the shell, which re-parses it.
Singleton {
    id: idx

    // files: parsed in this order (a page's composite rows like BatteryInfo / GpuSwitch count as the page)
    readonly property var sections: [
        { id: "network",    word: "network",   caption: "network · wi-fi, wired, tethering", files: ["NetPage.qml"],
          keywords: "wifi internet ethernet" },
        { id: "bluetooth",  word: "bluetooth", caption: "bluetooth · devices, pairing", files: ["BtPage.qml"], keywords: "bt" },
        { id: "sound",      word: "sound",     caption: "sound · levels, devices, apps", files: ["AudioPage.qml"],
          keywords: "audio volume speakers microphone" },
        { id: "appearance", word: "look",      caption: "look · wallpaper, home screen, colours, sizes", files: ["SetAppearance.qml"],
          keywords: "appearance theme style" },
        { id: "shell",      word: "shell",     caption: "shell · home screen, dock, osd, notifications", files: ["SetShell.qml"],
          keywords: "aurora" },
        { id: "windows",    word: "windows",   caption: "windows · hyprland gaps, borders, effects, layout", files: ["SetWindows.qml"],
          keywords: "hyprland tiling" },
        { id: "input",      word: "input",     caption: "input · keyboard, mouse, touchpad", files: ["SetInput.qml"], keywords: "" },
        { id: "keybinds",   word: "keys",      caption: "keys · hyprland binds", files: [],
          keywords: "keybinds shortcuts hotkeys bindings" },
        { id: "display",    word: "display",   caption: "display · monitors, layout, night light", files: ["SetDisplay.qml"],
          keywords: "screen monitor resolution" },
        { id: "power",      word: "power",     caption: "power · battery, profiles, idle", files: ["BatteryInfo.qml", "SetPower.qml", "GpuSwitch.qml"],
          keywords: "energy sleep" },
        { id: "about",      word: "about",     caption: "about · this system", files: ["SetAbout.qml"], keywords: "info version" }
    ]

    // rows the parser can't see. group = the SectionLabel to land on ("" = the top of the section)
    readonly property var extras: [
        { section: "network", group: "", label: "wi-fi on / off", hint: "rescan for networks",
          keywords: "wifi wireless wlan radio internet scan" },
        { section: "network", group: "networks", label: "wi-fi networks", hint: "connect, password, forget",
          keywords: "wifi ssid connect password forget hotspot" },
        { section: "bluetooth", group: "", label: "bluetooth on / off", hint: "search for devices",
          keywords: "bt adapter radio discover scan" }
    ]

    readonly property string dir: Quickshell.env("HOME") + "/.config/quickshell/aurora/"
    property var parsed: ({})          // file -> [{kind, group, label, hint, keywords, context}]

    readonly property var files: {
        var out = []
        for (var i = 0; i < sections.length; i++)
            for (var j = 0; j < sections[i].files.length; j++) out.push(sections[i].files[j])
        return out
    }
    Variants {
        model: idx.files
        FileView {
            required property string modelData
            path: idx.dir + modelData
            onLoaded: idx.parse(modelData, text())
        }
    }

    // every entry: {kind: section|group|row, section, word, group, label, hint, order, l, k, c, h}
    // l/k/c/h = lowercased label / keywords (own synonyms, options) / context (section, group + its keywords) / hint,
    // for search()
    readonly property var entries: {
        var out = []
        function add(s, e) {
            out.push({ kind: e.kind, section: s.id, word: s.word, group: e.group, label: e.label, hint: e.hint,
                       order: out.length, l: norm(e.label), k: norm(e.keywords),
                       c: norm(s.word + " " + s.id + " " + (e.context || "")), h: norm(e.hint) })
        }
        for (var i = 0; i < sections.length; i++) {
            var s = sections[i]
            add(s, { kind: "section", group: "", label: s.word, hint: s.caption.replace(/^[^·]*·\s*/, ""),
                     keywords: s.id + " " + s.keywords })
            for (var j = 0; j < s.files.length; j++) {
                var p = parsed[s.files[j]] || []
                for (var n = 0; n < p.length; n++) add(s, p[n])
            }
            for (var x = 0; x < extras.length; x++)
                if (extras[x].section === s.id)
                    add(s, { kind: "group", group: extras[x].group,
                             label: extras[x].label, hint: extras[x].hint, keywords: extras[x].keywords })
        }
        return out
    }

    // the text of `key: "literal"` at the block's own level, or null (expressions don't count)
    function lit(top, key) {
        var m = new RegExp("(?:^|[\\s;])" + key + ":\\s*\"((?:[^\"\\\\]|\\\\.)*)\"\\s*(?:;|\\n|$)").exec(top)
        return m ? m[1].replace(/\\(.)/g, "$1") : null
    }
    // from just after a `{`: the block's own text (nested {} [] left out) and the nested text, skipping strings/comments
    function block(t, i) {
        var depth = 1, top = "", inner = "", q = ""
        for (; i < t.length && depth > 0; i++) {
            var ch = t[i]
            if (q !== "") {
                if (depth === 1) top += ch; else inner += ch
                if (ch === "\\") { i++; if (depth === 1) top += t[i]; else inner += t[i] }
                else if (ch === q) q = ""
                continue
            }
            if (ch === "/" && t[i + 1] === "/") { var nl = t.indexOf("\n", i); i = (nl < 0 ? t.length : nl) - 1; continue }
            if (ch === '"' || ch === "'" || ch === "`") q = ch
            if (ch === "{" || ch === "[") { depth++; continue }
            if (ch === "}" || ch === "]") { depth--; continue }
            if (depth === 1) top += ch; else inner += ch
        }
        return { top: top, inner: inner }
    }
    function parse(file, t) {
        var out = [], group = "", groupKw = "", re = /\b(SectionLabel|Switch|Knob|Choice|Field|Timeout|IconBtn)\s*\{/g, m
        while ((m = re.exec(t)) !== null) {
            var b = block(t, re.lastIndex), kw = lit(b.top, "keywords")
            if (m[1] === "SectionLabel") {
                group = lit(b.top, "text") || ""
                groupKw = group !== "" ? kw || "" : ""
                if (group !== "") out.push({ kind: "group", group: group, label: group, hint: "", keywords: groupKw, context: "" })
                continue
            }
            var label = lit(b.top, "label")
            if (!label || (m[1] === "IconBtn" && kw === null)) continue
            var opts = []
            if (m[1] === "Choice") {
                var om, ore = /\blabel:\s*"([^"]*)"/g
                while ((om = ore.exec(b.inner)) !== null) opts.push(om[1])
            }
            out.push({ kind: "row", group: group, label: label, hint: lit(b.top, "hint") || "",
                       keywords: (kw || "") + " " + opts.join(" "), context: group + " " + groupKw })
        }
        var p = Object.assign({}, parsed)
        p[file] = out
        parsed = p
    }

    // every word has to match the entry (its own text or its section/group); at least one its own text.
    // own: label prefix > a label word > keywords > a hint word > inside a label word. Best first, then page order.
    // A hyphenated word is indexed split and joined ("24-hour" -> "24 hour 24hour"), the query joins them ("wi-fi" = "wifi").
    function norm(s) {
        s = s.toLowerCase()
        return " " + s.replace(/-/g, " ") + (s.indexOf("-") >= 0 ? " " + s.replace(/-/g, "") : "")
    }
    function search(q) {
        var words = q.toLowerCase().replace(/-/g, "").trim().split(/\s+/).filter(function (w) { return w !== "" })
        if (!words.length) return []
        var hits = []
        for (var i = 0; i < entries.length; i++) {
            var e = entries[i], total = 0, own = false
            for (var j = 0; j < words.length; j++) {
                var w = words[j], at = e.l.indexOf(" " + w)
                var sc = Math.max(at === 0 ? 1000 : at > 0 ? 500 : e.l.indexOf(w) > 0 ? 60 : 0,
                                  e.k.indexOf(" " + w) >= 0 ? 250 : e.k.indexOf(w) >= 0 ? 150
                                  : e.h.indexOf(" " + w) >= 0 ? 80 : 0)
                if (sc > 0) own = true
                else sc = e.c.indexOf(" " + w) >= 0 ? 200 : e.c.indexOf(w) >= 0 ? 100 : 0
                if (sc <= 0) { total = 0; break }
                total += sc
            }
            if (total > 0 && own) hits.push({ e: e, sc: total })
        }
        hits.sort(function (a, b) { return b.sc - a.sc || a.e.order - b.e.order })
        var res = []
        for (var n = 0; n < hits.length && n < 60; n++) res.push(hits[n].e)
        return res
    }
}
