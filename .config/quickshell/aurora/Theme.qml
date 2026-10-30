pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// The design system: Nothing OS's shapes, dots and type (after glyph-rice) in Android Material You colours from matugen
// (~/.cache/matugen/aurora.json, written by Wall.apply/recolor, hot-reloaded), plus fonts, motion and all icon glyphs.
Singleton {
    id: root

    // ---- fonts ----
    readonly property string dot: "Doto"                  // numbers and short words (Num), never under 26px
    readonly property string ui: "Space Grotesk"          // UI text: titles DemiBold, body Regular, greeting Light
    readonly property string mono: "Space Mono"           // caps labels (Lb)
    readonly property string nf: "JetBrainsMono Nerd Font"   // icons only (Icon)

    // ---- knobs (persisted in ~/.config/aurora/settings.json, edited in the settings app) ----
    readonly property real panelAlpha: Settings.panelAlpha
    readonly property bool barVertical: Settings.barLayout === "vertical"   // docked at the left edge instead of the top
    readonly property int barSize: barVertical ? Math.max(48, Settings.barWidth) : Math.max(32, Settings.barSize)   // its thickness
    readonly property bool barFloat: Settings.barFloat               // a floating pill instead of a strip along the edge
    readonly property int barGap: barFloat ? 14 : 0                  // the pill's distance from the screen edges (glyph-rice)
    // ... and from the windows: glyph's 14 too, there it is Hyprland's gaps_out; here only the part gaps_out doesn't cover
    readonly property int barInner: barFloat ? Math.max(0, barGap - (HyprConf.values["general:gaps_out"] || 0)) : 0
    readonly property int barSpan: barSize + barGap + barInner       // the bar window, across the bar
    readonly property int barTop: barVertical ? 0 : barSpan          // what the bar reserves at the top
    readonly property int barLeft: barVertical ? barSpan : 0         // ... and at the left
    readonly property real barAlpha: Settings.barAlpha

    // ---- motion: ease-out-quart without overshoot (glyph's "glide"); Settings.motion off = instant ----
    readonly property bool motion: Settings.motion
    readonly property int t: motion ? 350 : 0
    readonly property var glide: [0.25, 1, 0.5, 1, 1, 1]

    readonly property string matFile: Quickshell.env("HOME") + "/.cache/matugen/aurora.json"

    // Material 3 roles from ~/.config/matugen/templates/aurora.json ("on_x" is spelled "xFg": JsonAdapter keys must not
    // start with "on" + uppercase or be "error"). Defaults = a dark teal scheme for a fresh install.
    FileView {
        path: root.matFile
        watchChanges: true
        onFileChanged: reload()
        adapter: JsonAdapter {
            id: mat
            property string primary: "#80d5cb"
            property string primaryFg: "#003733"
            property string primaryContainer: "#00504a"
            property string primaryContainerFg: "#9cf2e7"
            property string secondary: "#b1ccc7"
            property string secondaryFg: "#1c3532"
            property string secondaryContainer: "#334b48"
            property string secondaryContainerFg: "#cce8e3"
            property string tertiary: "#adcae6"
            property string tertiaryFg: "#153349"
            property string tertiaryContainer: "#2d4961"
            property string tertiaryContainerFg: "#cce5ff"
            property string surface: "#0e1514"
            property string surfaceLowest: "#090f0f"
            property string surfaceLow: "#161d1c"
            property string surfaceContainer: "#1a2120"
            property string surfaceHigh: "#252b2a"
            property string surfaceHighest: "#2f3635"
            property string surfaceFg: "#dde4e2"
            property string surfaceVariantFg: "#bec9c6"
            property string outline: "#889391"
            property string outlineVariant: "#3f4947"
            property string err: "#ffb4ab"
            property string errFg: "#690005"
        }
    }

    // ---- palette ------------------------------------------------------
    // Nothing's ladder of steps, filled with Material roles, so every wallpaper re-themes everything.
    readonly property color bg: mat.surfaceLowest      // wallpaper backdrop, fullscreen overlays
    readonly property color s1: mat.surfaceLow         // bar, panels, cards
    readonly property color s2: mat.surfaceHigh        // tiles, rows, "off" fills, inputs
    readonly property color s3: mat.surfaceHighest     // lines, unlit dots, hover
    readonly property color mute: mat.outlineVariant   // inactive
    readonly property color grey: mat.outline         // caps labels
    readonly property color fg: mat.surfaceFg          // text
    readonly property color fgDim: mat.surfaceVariantFg   // secondary text (artist, notification body)
    // "on" states, Material You style: active tiles/pills, slider fills, selected chips/rows, lit dots and segments
    readonly property color fill: mat.primary
    readonly property color fillFg: mat.primaryFg
    readonly property color container: mat.primaryContainer   // tonal emphasis
    readonly property color containerFg: mat.primaryContainerFg
    // live things (Nothing's one red thing): play button, recording, mic/cam/share, caret, selected dot, newest notification
    readonly property color live: mat.tertiary
    readonly property color liveFg: mat.tertiaryFg
    readonly property color err: mat.err               // failures, critical, destructive confirms
    readonly property color errFg: mat.errFg
    readonly property color glow: fade(fill, 0.6)      // glow on lit segments, the only "shadow"
    readonly property color scrim: fade(bg, 0.74)      // dim behind fullscreen overlays

    function fade(c, a) { return Qt.rgba(c.r, c.g, c.b, a) }
    function hex(c) { return c.toString().slice(1, 7).toUpperCase() }
    // slurp in the theme: the screen dims, the selection gets a 1px primary outline (Rec, Shot's OCR)
    readonly property var slurpArgs: ["-b", "#" + hex(bg) + "88", "-c", "#" + hex(fill) + "ff", "-s", "#00000000", "-w", "1"]
    // hours for the 12/24h setting: "09" or "9"
    function hh(d) {
        var h = d.getHours()
        return Settings.clock24 ? (h < 10 ? "0" : "") + h : String(h % 12 || 12)
    }

    // ---- hyprlock -----------------------------------------------------
    // hyprlock stays a separate process (crash safety); it sources ~/.config/aurora/hyprlock-colors.conf,
    // written here so the lock uses the resolved palette (incl. the settings-picked accent). `$xHex` = "##rrggbb" for
    // Pango markup (hyprlang reads "##" as "#"), plus the clock/battery settings its labels need (~/.local/bin/hypr/lockinfo).
    // Its pictures (the wallpaper as drawn here, the avatar ring) are LockArt's.
    readonly property string lockFile: Quickshell.env("HOME") + "/.config/aurora/hyprlock-colors.conf"
    readonly property string lockConf: {
        function c(v) {
            var h = n => ("0" + Math.round(n * 255).toString(16)).slice(-2)
            return "rgba(" + h(v.r) + h(v.g) + h(v.b) + h(v.a) + ")"
        }
        function x(v) { return "##" + hex(v).toLowerCase() }
        return ["# generated by aurora (Theme.qml); edit the palette there, not here",
            "$bg = " + c(bg), "$fg = " + c(fg), "$fgDim = " + c(fgDim), "$s1 = " + c(s1), "$s2 = " + c(s2), "$s3 = " + c(s3),
            "$mute = " + c(mute), "$grey = " + c(grey), "$fill = " + c(fill), "$fillFg = " + c(fillFg), "$live = " + c(live),
            "$err = " + c(err), "$dot = " + dot + " Black", "$ui = " + ui, "$mono = " + mono,
            "$fgHex = " + x(fg), "$s3Hex = " + x(s3), "$greyHex = " + x(grey), "$liveHex = " + x(live), "$errHex = " + x(err),
            "$hourFmt = " + (Settings.clock24 ? "%H" : "%-I"), "$blink = " + (Settings.blink ? 1 : 0),
            "$batLow = " + Settings.batLow,
            ""].join("\n")
    }
    onLockConfChanged: lockTimer.restart()
    Timer { id: lockTimer; interval: 500; onTriggered: lockFv.setText(root.lockConf) }
    FileView { id: lockFv; path: root.lockFile; printErrors: false }
    Component.onCompleted: lockTimer.restart()

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
    readonly property string iLogin: cp(0xF0342)
    readonly property string iMouse: cp(0xF037D)
    readonly property string iKeyboard: cp(0xF030C)
    readonly property string iPhone: cp(0xF011C)
    readonly property string iGamepad: cp(0xF0297)
    readonly property string iSearch: cp(0xF0349)
    // glyph picker sections
    readonly property string iGrid: cp(0xF11D9)
    readonly property string iHistory: cp(0xF02DA)
    readonly property string iEmoji: cp(0xF01F5)
    readonly property string iFontGlyph: cp(0xF06D6)
    readonly property string iSigma: cp(0xF04A0)
    readonly property string iKaomoji: cp(0xF01F3)
    readonly property string iFancy: cp(0xF0B34)
    readonly property string iBuffer: cp(0xF1296)

    readonly property string iHeadset: cp(0xF02CE)
    readonly property string iCamera: cp(0xF0100)
    readonly property string iWebcam: cp(0xF05A0)
    readonly property string iCast: cp(0xF0118)
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
    readonly property string iUsb: cp(0xF129B)
    readonly property string iEject: cp(0xF01EA)
    readonly property string iUpdate: cp(0xF03D5)   // package up
    readonly property string iFolderOpen: cp(0xF0770)
    readonly property string iGpu: cp(0xF08AE)
    readonly property string iLeaf: cp(0xF032A)
    readonly property string iBalance: cp(0xF05D1)
    readonly property string iSpeed: cp(0xF04C5)
    readonly property string iAuto: cp(0xF006A)     // autorenew
    readonly property string iCal: cp(0xF00ED)
    readonly property string iClock: cp(0xF0954)
    readonly property string iArch: cp(0xF08C7)
    readonly property string iEthernet: cp(0xF0200)
    readonly property string iPlug: cp(0xF06A5)
    readonly property string iBatCharge: cp(0xF0084)
    readonly property string iShuffle: cp(0xF049D)
    readonly property string iImage: cp(0xF02E9)
    readonly property string iCoffee: cp(0xF0176)
    readonly property string iPlane: cp(0xF001D)
    readonly property string iPicker: cp(0xF020A)
    readonly property string iRec: cp(0xF044A)
    readonly property string iStop: cp(0xF04DB)
    readonly property string iDock: cp(0xF10A9)
    readonly property string iCog: cp(0xF0493)
    readonly property string iApps: cp(0xF003B)
    readonly property string iApp: cp(0xF08C6)
    readonly property string iConsole: cp(0xF018D)
    readonly property string iShell: cp(0xF07B7)
    readonly property string iCalc: cp(0xF00EC)
    readonly property string iPalette: cp(0xF03D8)
    readonly property string iChevron: cp(0xF0142)      // right
    readonly property string iChevronLeft: cp(0xF0141)
    readonly property string iChevronDown: cp(0xF0140)
    readonly property string iChevronUp: cp(0xF0143)
    readonly property string iNight: cp(0xF0594)        // weather-night (night light)
    readonly property string iShot: cp(0xF0E51)         // monitor-screenshot
    readonly property string iOcr: cp(0xF113D)          // text-recognition
    readonly property string iBolt: cp(0xF140B)         // lightning-bolt (charging)
    readonly property string iDots: cp(0xF01D8)         // dots-horizontal
    readonly property string iDashboard: cp(0xF056E)    // view-dashboard (overview)
    readonly property string iText: cp(0xF0262)         // format-align-left
    readonly property string iLink: cp(0xF0339)         // link-variant
    readonly property string iCode: cp(0xF0169)         // code-braces
    // weather (Weather.icon picks one per WMO code)
    readonly property string iSunny: cp(0xF0599)
    readonly property string iPartlyCloudy: cp(0xF0595)
    readonly property string iNightCloudy: cp(0xF0F31)  // weather-night-partly-cloudy
    readonly property string iCloudy: cp(0xF0590)
    readonly property string iFog: cp(0xF0591)
    readonly property string iRain: cp(0xF0597)
    readonly property string iPouring: cp(0xF0596)
    readonly property string iSnow: cp(0xF0598)
    readonly property string iThunder: cp(0xF0593)
    readonly property string iSunrise: cp(0xF059C)      // weather-sunset-up
    readonly property string iSunset: cp(0xF059B)       // weather-sunset-down
    readonly property string iArrowDown: cp(0xF0045)
    readonly property string iArrowUp: cp(0xF005D)

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

    function fmtClock(s) {                 // 75 -> "1:15"
        var m = Math.floor(s / 60), r = s % 60
        return m + ":" + (r < 10 ? "0" : "") + r
    }
    function volIcon(v, muted) {
        if (muted || v <= 0) return iVolOff
        return v < 0.34 ? iVolLow : (v < 0.67 ? iVolMed : iVolHigh)
    }
    function wifiIcon(sig) {
        return cp(sig >= 75 ? 0xF0928 : sig >= 50 ? 0xF0925 : sig >= 25 ? 0xF0922 : 0xF091F)
    }
}
