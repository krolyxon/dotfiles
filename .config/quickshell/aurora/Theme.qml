pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// pywal16 colours (~/.cache/wal/colors.json), hot-reloaded whenever `wal` runs.
Singleton {
    id: root

    // ---- knobs --------------------------------------------------------
    property string font: "JetBrainsMono Nerd Font"   // any Nerd Font mono
    property int fontSize: 12
    property int wsFontSize: 11          // workspace icons only; everything else uses fontSize
    property real panelAlpha: 0.88
    // your waybar uses @color14 for underlines/active workspace, so that is the default.
    // set -1 to auto-pick the most vivid of color1..color6 instead
    property int accentIndex: 14
    property int barHeight: 22
    property real barAlpha: 1.0

    readonly property string walFile: Quickshell.env("HOME") + "/.cache/wal/colors.json"

    FileView {
        path: root.walFile
        watchChanges: true
        onFileChanged: reload()
        adapter: JsonAdapter {
            id: wal
            property JsonObject special: JsonObject {
                property string background: "#0b1514"
                property string foreground: "#cfe3df"
                property string cursor: "#cfe3df"
            }
            property JsonObject colors: JsonObject {
                property string color0: "#0b1514"
                property string color1: "#c0616b"
                property string color2: "#3fa593"
                property string color3: "#7fb6a8"
                property string color4: "#3a8f8a"
                property string color5: "#5f9f9a"
                property string color6: "#4fbfae"
                property string color7: "#cfe3df"
                property string color8: "#4a5f5c"
                property string color9: "#d97a84"
                property string color10: "#52c2ae"
                property string color11: "#9ad0c3"
                property string color12: "#4fb0a9"
                property string color13: "#78b8b2"
                property string color14: "#6fd6c5"
                property string color15: "#e3f2ef"
            }
        }
    }

    readonly property var pal: [
        wal.colors.color0, wal.colors.color1, wal.colors.color2, wal.colors.color3,
        wal.colors.color4, wal.colors.color5, wal.colors.color6, wal.colors.color7,
        wal.colors.color8, wal.colors.color9, wal.colors.color10, wal.colors.color11,
        wal.colors.color12, wal.colors.color13, wal.colors.color14, wal.colors.color15
    ]

    function mix(a, b, t) {
        return Qt.rgba(a.r + (b.r - a.r) * t, a.g + (b.g - a.g) * t, a.b + (b.b - a.b) * t, 1)
    }

    function autoAccent() {
        var best = 4, score = -1
        for (var i = 1; i <= 6; i++) {
            var c = Qt.color(pal[i])
            var s = c.hsvSaturation * c.hsvValue
            if (s > score) { score = s; best = i }
        }
        return Qt.color(pal[best])
    }

    // ---- palette ------------------------------------------------------
    readonly property color bg: wal.special.background
    readonly property color fg: wal.special.foreground
    readonly property color accent: accentIndex >= 0 ? Qt.color(pal[accentIndex]) : autoAccent()
    readonly property color accentDim: mix(bg, accent, 0.45)
    readonly property color surface: mix(bg, fg, 0.06)
    readonly property color surfaceHi: mix(bg, fg, 0.14)
    readonly property color line: mix(bg, accent, 0.35)
    readonly property color dim: mix(bg, fg, 0.55)
    readonly property color err: Qt.color(pal[1])
    readonly property color barBg: Qt.rgba(bg.r, bg.g, bg.b, barAlpha)
    readonly property color cursorC: wal.special.cursor
    readonly property color bgA: Qt.rgba(bg.r, bg.g, bg.b, panelAlpha)

    // ---- Nerd Font (Material Design) glyphs ---------------------------
    function cp(c) {
        c -= 0x10000
        return String.fromCharCode(0xD800 + (c >> 10), 0xDC00 + (c & 0x3FF))
    }
    readonly property string iHome: cp(0xF02DC)
    readonly property string iVolHigh: cp(0xF057E)
    readonly property string iVolMed: cp(0xF0580)
    readonly property string iVolLow: cp(0xF057F)
    readonly property string iVolOff: cp(0xF0581)
    readonly property string iMic: cp(0xF036C)
    readonly property string iMicOff: cp(0xF036D)
    readonly property string iWifi: cp(0xF05A9)
    readonly property string iWifiOff: cp(0xF05AA)
    readonly property string iBt: cp(0xF00AF)
    readonly property string iBtOff: cp(0xF00B2)
    readonly property string iBtConn: cp(0xF00B1)
    readonly property string iPower: cp(0xF0425)
    readonly property string iClose: cp(0xF0156)
    readonly property string iPrev: cp(0xF04AE)
    readonly property string iNext: cp(0xF04AD)
    readonly property string iPlay: cp(0xF040A)
    readonly property string iPause: cp(0xF03E4)
    readonly property string iBright: cp(0xF00DF)
    readonly property string iLock: cp(0xF033E)
    readonly property string iLogout: cp(0xF0343)
    readonly property string iSleep: cp(0xF04B2)
    readonly property string iReboot: cp(0xF0709)
    readonly property string iRefresh: cp(0xF0450)
    readonly property string iHeadphones: cp(0xF02CB)
    readonly property string iSpeaker: cp(0xF04C3)
    readonly property string iMusic: cp(0xF075A)
    readonly property string iTrash: cp(0xF01B4)
    readonly property string iCheck: cp(0xF012C)
    readonly property string iMouse: cp(0xF037D)
    readonly property string iKeyboard: cp(0xF030C)
    readonly property string iPhone: cp(0xF011C)
    readonly property string iGamepad: cp(0xF0297)
    readonly property string iSearch: cp(0xF0349)

    readonly property string iHeadset: cp(0xF02CE)
    readonly property string iCamera: cp(0xF0100)
    readonly property string iCrop: cp(0xF019E)
    readonly property string iWindow: cp(0xF05B0)
    readonly property string iMonitor: cp(0xF0379)
    readonly property string iSave: cp(0xF0193)
    readonly property string iClipboard: cp(0xF0147)
    readonly property string iBell: cp(0xF009A)
    readonly property string iBellOff: cp(0xF009B)
    readonly property string iChip: cp(0xF061A)
    readonly property string iMem: cp(0xF035B)
    readonly property string iDisk: cp(0xF02CA)
    readonly property string iGpu: cp(0xF08AE)
    readonly property string iLeaf: cp(0xF032A)
    readonly property string iBalance: cp(0xF05D1)
    readonly property string iSpeed: cp(0xF04C5)
    readonly property string iCal: cp(0xF00ED)
    readonly property string iClock: cp(0xF0954)
    readonly property string iArch: cp(0xF08C7)
    readonly property string iEthernet: cp(0xF0200)
    readonly property string iPlug: cp(0xF06A5)
    readonly property string iBatCharge: cp(0xF0084)

    // workspace icons: the exact Font Awesome glyphs from your waybar config.
    // 1 browser, 2 code, 3 book, 4 cog, 5 chat, 6 file, 7 folder, 8 terminal, 9 flask, 10 image
    // 11-20 repeat the same ten, like your waybar format-icons did
    readonly property var wsIcons: [
        String.fromCharCode(0xf269), String.fromCharCode(0xf121), String.fromCharCode(0xf02d),
        String.fromCharCode(0xf085), String.fromCharCode(0xf086), String.fromCharCode(0xf1c9),
        String.fromCharCode(0xf07c), String.fromCharCode(0xf120), String.fromCharCode(0xf0c3),
        String.fromCharCode(0xf03e)
    ]
    function wsIcon(id) { return id >= 1 ? wsIcons[(id - 1) % 10] : String(id) }

    readonly property var batLevels: [0xF007A, 0xF007B, 0xF007C, 0xF007D, 0xF007E,
                                      0xF007F, 0xF0080, 0xF0081, 0xF0082, 0xF0079]
    function batIcon(p, charging, plugged) {
        if (charging) return iBatCharge
        if (plugged) return iPlug
        return cp(batLevels[Math.max(0, Math.min(9, Math.floor(p * 10)))])
    }
    function fmtTime(s) {
        if (!s || s <= 0) return "-"
        var h = Math.floor(s / 3600), m = Math.floor((s % 3600) / 60)
        return h > 0 ? h + "h " + m + "m" : m + "m"
    }

    function volIcon(v, muted) {
        if (muted || v <= 0) return iVolOff
        return v < 0.34 ? iVolLow : (v < 0.67 ? iVolMed : iVolHigh)
    }
    function wifiIcon(sig) {
        return cp(sig >= 75 ? 0xF0928 : sig >= 50 ? 0xF0925 : sig >= 25 ? 0xF0922 : 0xF091F)
    }
}
