pragma Singleton
import QtQuick
import Quickshell

// Screenshots, ported from your fuzzel script. Needs: hyprshot (+ grim, slurp), and for
// OCR: tesseract + wl-clipboard. Used by the Home tab and by `ipc call shell shot <mode>`.
Singleton {
    id: root

    property bool save: false                                   // false = clipboard, true = file
    property string dir: Quickshell.env("HOME") + "/pix/ss"     // where "save" puts files
    property string ocrLang: "eng"

    readonly property var names: ({ region: "selected", window: "window", output: "full" })

    // mode: "region" | "window" | "output" | "ocr"
    function take(mode) {
        var script
        if (mode === "ocr") {
            script = 'slurp | grim -g - - | tesseract stdin stdout -l "$2" | wl-copy'
                   + ' && notify-send -a screenshot "OCR" "text copied to clipboard"'
        } else if (names[mode] === undefined) {
            return
        } else if (!save) {
            script = 'hyprshot -m ' + mode + ' --clipboard-only'
        } else {
            script = 'mkdir -p "$1"; hyprshot -m ' + mode + ' -o "$1"'
                   + ' -f "pic-' + names[mode] + '-$(date +%y-%m-%d_%H%M%S).png"'
        }
        // short delay so the panel is gone before the capture starts
        Quickshell.execDetached(["sh", "-c", "sleep 0.35; " + script, "sh", dir, ocrLang])
    }
}
