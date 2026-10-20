pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Glyph data for CharPicker: chars.json (emoji, nerd font, unicode symbols, kaomoji; built by
// chars-gen.py), use counts in ~/.cache/aurora/chars.json, fancy text styles, copy / type.
// The 900K json is only parsed the first time the picker opens.
Singleton {
    id: root
    readonly property string home: Quickshell.env("HOME")
    property bool loaded: false
    property var sets: []          // [{id, label, groups: [label]}]
    property var items: []         // [{c, n, k, s, g, t, nl, kl}], t = 5 skin-tone variants or undefined
    property var byChar: ({})
    property var counts: ({})      // char -> {n: uses, t: last used ms}
    property bool hasWtype: false

    function load() { if (data.path === "") data.path = home + "/.config/quickshell/aurora/chars.json" }
    // parse it in the background a bit after startup, so the first SUPER+grave is instant
    Timer { interval: 5000; running: true; onTriggered: root.load() }

    FileView {
        id: data
        printErrors: true
        onLoaded: {
            var d
            try { d = JSON.parse(text()) } catch (e) { console.warn("chars.json:", e); return }
            var out = [], by = {}, l = d.items
            for (var i = 0; i < l.length; i++) {
                var r = l[i]
                var it = { i: i, c: r[0], n: r[1], k: r[2], s: r[3], g: r[4], t: r[5],
                           nl: r[1].toLowerCase(), kl: " " + r[2].toLowerCase() + " " + d.sets[r[3]].groups[r[4]].toLowerCase() + " " }
                out.push(it)
                if (by[it.c] === undefined) by[it.c] = it
            }
            root.sets = d.sets
            root.byChar = by
            root.items = out
            root.loaded = true
        }
    }
    FileView {
        id: store
        path: root.home + "/.cache/aurora/chars.json"
        printErrors: false
        onLoaded: { try { root.counts = JSON.parse(text()) } catch (e) { root.counts = {} } }
    }
    Process {
        command: ["sh", "-c", "command -v wtype"]
        running: true
        onExited: code => root.hasWtype = code === 0
    }

    function setIndex(id) {
        for (var i = 0; i < sets.length; i++) if (sets[i].id === id) return i
        return -1
    }
    // the glyph to output for an item: skin tone applied when it has variants
    function glyph(it, tone) { return it.t && tone > 0 ? it.t[tone - 1] : it.c }
    function hex(c) {
        var out = [], i = 0
        while (i < c.length) {
            var cp = c.codePointAt(i)
            if (cp !== 0xFE0F && cp !== 0x200D) out.push("U+" + cp.toString(16).toUpperCase().padStart(4, "0"))
            i += cp > 0xFFFF ? 2 : 1
        }
        return out.join(" ")
    }

    // ---- search ----
    // sets: list of set indexes to search, group: -1 or a group of a single set.
    // Every query word must match the name (fuzzy) or a keyword (word start / substring).
    // Also: a pasted glyph, or a codepoint (u+f0001, 0xf0001, f0001).
    function search(q, sl, group) {
        var out = [], l = items
        q = q.trim().toLowerCase()
        var inSet = {}
        for (var j = 0; j < sl.length; j++) inSet[sl[j]] = true
        if (q === "") {
            for (var i = 0; i < l.length; i++)
                if (inSet[l[i].s] && (group < 0 || l[i].g === group)) out.push(l[i])
            return out
        }
        var cpm = q.match(/^(?:u\+|0x|\\u)([0-9a-f]{2,6})$/), cpq = -1
        if (cpm) cpq = parseInt(cpm[1], 16)
        else if (/^[0-9a-f]{4,6}$/.test(q) && /[0-9]/.test(q)) cpq = parseInt(q, 16)   // "face" is a word, "f001" a codepoint
        var glyphq = /[^\x00-\x7f]/.test(q) ? q : ""
        var words = q.split(/\s+/), scored = []
        for (i = 0; i < l.length; i++) {
            var it = l[i]
            if (!inSet[it.s] || (group >= 0 && it.g !== group)) continue
            var sc = 0
            if (glyphq !== "") {
                if (it.c === glyphq || it.c.replace("️", "") === glyphq.replace("️", "")) sc = 5000
            } else if (cpq >= 0 && it.c.codePointAt(0) === cpq && it.c.length <= 2) {
                sc = 5000
            } else {
                for (j = 0; j < words.length; j++) {
                    var w = words[j]
                    var s = Fuzzy.scoreLow(it.nl, w)
                    if (s < 300 && s < 99) s = 0   // scattered: one skipped letter at most ("thmbs"), not letters strewn over a name
                    if (s < 450 && it.kl.indexOf(" " + w) >= 0) s = 450
                    else if (s < 150 && w.length > 1 && it.kl.indexOf(w) >= 0) s = 150
                    if (s === 0) { sc = 0; break }
                    sc += s
                }
                if (sc === 0) continue
                if (it.nl === q) sc += 800
                sc -= it.nl.length * 0.5
                if (sets[it.s].id === "emoji") sc += 40   // 11k nerd glyphs shouldn't drown the emoji
            }
            if (sc <= 0) continue
            var u = counts[it.c]
            if (u) sc += Math.min(u.n, 20) * 15
            scored.push({ it: it, sc: sc })
        }
        scored.sort((a, b) => b.sc - a.sc || a.it.i - b.it.i)   // ties keep file order (canonical ¯\_(ツ)_/¯ first)
        for (i = 0; i < scored.length; i++) out.push(scored[i].it)
        return out
    }
    // most recently used first; kaomoji excluded (they live in their own list view)
    function recent(limit) {
        var l = []
        for (var c in counts) {
            var it = byChar[c]
            if (it && sets[it.s].id !== "kao") l.push({ it: it, t: counts[c].t })
        }
        l.sort((a, b) => b.t - a.t)
        var out = []
        for (var i = 0; i < l.length && i < limit; i++) out.push(l[i].it)
        return out
    }
    // used kaomoji first (by count), rest in file order
    function byUse(list) {
        var u = [], rest = []
        for (var i = 0; i < list.length; i++) (counts[list[i].c] ? u : rest).push(list[i])
        u.sort((a, b) => counts[b.c].n - counts[a.c].n)
        return u.concat(rest)
    }
    function bump(c) {
        var n = {}
        for (var k in counts) n[k] = counts[k]
        n[c] = { n: (n[c] ? n[c].n : 0) + 1, t: Date.now() }
        counts = n
        store.setText(JSON.stringify(n))
    }

    // ---- output ----
    function copy(s) {
        Quickshell.execDetached(["sh", "-c", 'wl-copy -- "$1" && notify-send -a aurora -t 1500 "copied" "$1"', "sh", s])
    }
    // the picker closes first, so give the focus a moment to go back to the app
    function type(s) {
        Quickshell.execDetached(["sh", "-c", 'sleep 0.15; wtype -- "$1"', "sh", s])
    }

    // ---- fancy text ----
    // [label, A, a, 0] start codepoints in Mathematical Alphanumeric Symbols, holes filled from Letterlike
    readonly property var mathStyles: [
        ["bold", 0x1D400, 0x1D41A, 0x1D7CE], ["italic", 0x1D434, 0x1D44E, 0], ["bold italic", 0x1D468, 0x1D482, 0],
        ["script", 0x1D49C, 0x1D4B6, 0], ["bold script", 0x1D4D0, 0x1D4EA, 0],
        ["fraktur", 0x1D504, 0x1D51E, 0], ["bold fraktur", 0x1D56C, 0x1D586, 0],
        ["double-struck", 0x1D538, 0x1D552, 0x1D7D8], ["sans", 0x1D5A0, 0x1D5BA, 0x1D7E2],
        ["sans bold", 0x1D5D4, 0x1D5EE, 0x1D7EC], ["sans italic", 0x1D608, 0x1D622, 0],
        ["monospace", 0x1D670, 0x1D68A, 0x1D7F6]]
    readonly property var holes: ({
        "italic": { h: 0x210E },
        "script": { B: 0x212C, E: 0x2130, F: 0x2131, H: 0x210B, I: 0x2110, L: 0x2112, M: 0x2133, R: 0x211B,
                    e: 0x212F, g: 0x210A, o: 0x2134 },
        "fraktur": { C: 0x212D, H: 0x210C, I: 0x2111, R: 0x211C, Z: 0x2128 },
        "double-struck": { C: 0x2102, H: 0x210D, N: 0x2115, P: 0x2119, Q: 0x211A, R: 0x211D, Z: 0x2124 }
    })
    readonly property string smallCaps: "ᴀʙᴄᴅᴇꜰɢʜɪᴊᴋʟᴍɴᴏᴘǫʀꜱᴛᴜᴠᴡxʏᴢ"
    readonly property string flipLower: "ɐqɔpǝɟƃɥᴉɾʞlɯuodbɹsʇnʌʍxʎz"
    readonly property var flipOther: ({ "0": "0", "1": "Ɩ", "2": "ᄅ", "3": "Ɛ", "4": "ㄣ", "5": "ϛ", "6": "9", "7": "ㄥ",
        "8": "8", "9": "6", ".": "˙", ",": "'", "'": ",", "\"": "„", "?": "¿", "!": "¡", "(": ")", ")": "(",
        "[": "]", "]": "[", "{": "}", "}": "{", "<": ">", ">": "<", "_": "‾", "&": "⅋" })

    function mapLetters(t, f) {
        var out = "", l = Array.from(t)   // by codepoint, so emoji in the text survive
        for (var i = 0; i < l.length; i++) {
            var r = f(l[i], l[i].codePointAt(0))
            out += r === null ? l[i] : r
        }
        return out
    }
    function fancy(t) {
        var out = [], st = mathStyles
        for (var i = 0; i < st.length; i++) {
            var s = st[i], h = holes[s[0]] || {}
            out.push({ c: mapLetters(t, (ch, code) => {
                if (h[ch]) return String.fromCodePoint(h[ch])
                if (code >= 65 && code <= 90) return String.fromCodePoint(s[1] + code - 65)
                if (code >= 97 && code <= 122) return String.fromCodePoint(s[2] + code - 97)
                if (code >= 48 && code <= 57 && s[3]) return String.fromCodePoint(s[3] + code - 48)
                return null
            }), n: s[0] })
        }
        out.push({ n: "small caps", c: mapLetters(t, (ch, code) => {
            var c = ch.toLowerCase().charCodeAt(0)
            return c >= 97 && c <= 122 ? smallCaps[c - 97] : null
        }) })
        out.push({ n: "full width", c: mapLetters(t, (ch, code) =>
            code === 32 ? "　" : (code > 32 && code < 127 ? String.fromCharCode(code + 0xFEE0) : null)) })
        out.push({ n: "circled", c: mapLetters(t, (ch, code) => {
            if (code >= 65 && code <= 90) return String.fromCodePoint(0x24B6 + code - 65)
            if (code >= 97 && code <= 122) return String.fromCodePoint(0x24D0 + code - 97)
            if (code === 48) return "⓪"
            if (code >= 49 && code <= 57) return String.fromCodePoint(0x2460 + code - 49)
            return null
        }) })
        out.push({ n: "negative circled", c: mapLetters(t, (ch, code) => {
            var c = ch.toUpperCase().charCodeAt(0)
            return c >= 65 && c <= 90 ? String.fromCodePoint(0x1F150 + c - 65) : null
        }) })
        out.push({ n: "squared", c: mapLetters(t, (ch, code) => {
            var c = ch.toUpperCase().charCodeAt(0)
            return c >= 65 && c <= 90 ? String.fromCodePoint(0x1F130 + c - 65) : null
        }) })
        out.push({ n: "negative squared", c: mapLetters(t, (ch, code) => {
            var c = ch.toUpperCase().charCodeAt(0)
            return c >= 65 && c <= 90 ? String.fromCodePoint(0x1F170 + c - 65) : null
        }) })
        out.push({ n: "strikethrough", c: mapLetters(t, (ch, code) => code === 32 ? null : ch + "̶") })
        out.push({ n: "underline", c: mapLetters(t, (ch, code) => ch + "̲") })
        out.push({ n: "upside down", c: Array.from(mapLetters(t, (ch, code) => {
            var c = ch.toLowerCase().charCodeAt(0)
            if (c >= 97 && c <= 122) return flipLower[c - 97]
            return flipOther[ch] !== undefined ? flipOther[ch] : null
        })).reverse().join("") })
        out.push({ n: "spaced", c: Array.from(t).join(" ") })
        return out
    }
}
