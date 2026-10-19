pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Bluetooth

// Small session toggles used by the Home tab and the bar.
Singleton {
    id: root

    // ---- caffeine: an IdleInhibitor on the bar (see Bar.qml) keeps hypridle from dimming/locking
    property bool caffeine: false

    // ---- airplane: wifi + bluetooth off, previous state restored when turned off again
    property bool airplane: false
    property bool hadWifi: true
    property bool hadBt: false
    function setAirplane(on) {
        var ad = Bluetooth.defaultAdapter
        if (on) {
            hadWifi = Net.wifiEnabled
            hadBt = ad ? ad.enabled : false
            Net.setWifi(false)
            if (ad) ad.enabled = false
        } else {
            if (hadWifi) Net.setWifi(true)
            if (ad && hadBt) ad.enabled = true
        }
        airplane = on
    }

    // ---- night light: gammastep (started by Hyprland) toggles on SIGUSR1. It starts enabled, and it
    // can't be asked, so the state is tracked here; hasNightLight = gammastep was running at startup.
    property bool hasNightLight: false
    property bool nightLight: true
    function setNightLight(on) {
        if (!hasNightLight || on === nightLight) return
        Quickshell.execDetached(["pkill", "-USR1", "-x", "gammastep"])
        nightLight = on
    }
    Process {
        command: ["pgrep", "-x", "gammastep"]
        running: true
        onExited: code => root.hasNightLight = code === 0
    }

    // ---- colour picker: hyprpicker copies the hex itself, we just show it as a notification
    property bool hasPicker: false
    function pickColour() { if (!picker.running) picker.running = true }
    Process {
        id: picker
        command: ["hyprpicker", "-a", "-f", "hex"]
        stdout: StdioCollector {
            onStreamFinished: {
                var c = text.trim()
                if (c !== "") Quickshell.execDetached(["notify-send", "-a", "aurora", "colour copied", c])
            }
        }
    }
    Process {
        command: ["sh", "-c", "command -v hyprpicker"]
        running: true
        onExited: code => root.hasPicker = code === 0
    }
}
