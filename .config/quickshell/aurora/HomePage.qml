import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Services.Pipewire

ColumnLayout {
    id: page
    spacing: 10
    signal closeRequested()
    signal overlayRequested(string name)

    property string armed: ""
    Timer { id: disarm; interval: 3000; onTriggered: page.armed = "" }

    function act(name, fn, confirm) {
        if (confirm && armed !== name) { armed = name; disarm.restart(); return }
        armed = ""
        fn()
        closeRequested()
    }

    Timer {
        interval: 3000
        running: page.visible
        repeat: true
        onTriggered: Bright.refresh()
    }

    MediaCard { Layout.fillWidth: true }

    SectionLabel { text: "levels" }

    SliderRow {
        Layout.fillWidth: true
        readonly property var audio: Pipewire.defaultAudioSink ? Pipewire.defaultAudioSink.audio : null
        icon: Theme.volIcon(audio ? audio.volume : 0, audio ? audio.muted : true)
        value: audio ? audio.volume : 0
        muted: audio ? audio.muted : false
        onMoved: v => { if (audio) audio.volume = v }
        onIconClicked: if (audio) audio.muted = !audio.muted
    }
    SliderRow {
        Layout.fillWidth: true
        readonly property var audio: Pipewire.defaultAudioSource ? Pipewire.defaultAudioSource.audio : null
        icon: audio && !audio.muted ? Theme.iMic : Theme.iMicOff
        value: audio ? audio.volume : 0
        muted: audio ? audio.muted : false
        onMoved: v => { if (audio) audio.volume = v }
        onIconClicked: if (audio) audio.muted = !audio.muted
    }
    SliderRow {
        Layout.fillWidth: true
        visible: Bright.available
        icon: Theme.iBright
        value: Bright.percent / 100
        valueText: Bright.percent + "%"
        onMoved: v => Bright.setPercent(Math.max(0.01, v) * 100)
    }

    SectionLabel { text: "quick toggles" }

    RowLayout {
        Layout.fillWidth: true
        spacing: 6
        IconBtn {
            Layout.fillWidth: true
            icon: Net.wifiEnabled ? Theme.iWifi : Theme.iWifiOff
            label: "wifi"
            active: Net.wifiEnabled
            onClicked: Net.setWifi(!Net.wifiEnabled)
        }
        IconBtn {
            Layout.fillWidth: true
            readonly property var ad: Bluetooth.defaultAdapter
            visible: ad !== null
            icon: ad && ad.enabled ? Theme.iBt : Theme.iBtOff
            label: "bt"
            active: ad ? ad.enabled : false
            onClicked: if (ad) ad.enabled = !ad.enabled
        }
        IconBtn {
            Layout.fillWidth: true
            icon: Notifs.dnd ? Theme.iBellOff : Theme.iBell
            label: "dnd"
            active: Notifs.dnd
            onClicked: Notifs.dnd = !Notifs.dnd
        }
        IconBtn {
            Layout.fillWidth: true
            readonly property var audio: Pipewire.defaultAudioSource ? Pipewire.defaultAudioSource.audio : null
            icon: audio && audio.muted ? Theme.iMicOff : Theme.iMic
            label: "mic"
            active: audio ? !audio.muted : false
            onClicked: if (audio) audio.muted = !audio.muted
        }
    }
    RowLayout {
        Layout.fillWidth: true
        spacing: 6
        IconBtn {
            Layout.fillWidth: true
            icon: Theme.iCoffee
            label: "caffeine"
            active: Toggles.caffeine
            onClicked: Toggles.caffeine = !Toggles.caffeine
        }
        IconBtn {
            Layout.fillWidth: true
            icon: Theme.iPlane
            label: "airplane"
            active: Toggles.airplane
            onClicked: Toggles.setAirplane(!Toggles.airplane)
        }
        IconBtn {
            Layout.fillWidth: true
            visible: Toggles.hasPicker
            icon: Theme.iPicker
            label: "colour"
            onClicked: { page.closeRequested(); Toggles.pickColour() }
        }
        IconBtn {   // click: record a region; while recording: stop
            Layout.fillWidth: true
            visible: Rec.available
            icon: Rec.busy ? Theme.iStop : Theme.iRec
            label: Rec.running ? Theme.fmtClock(Rec.elapsed) : (Rec.selecting ? "cancel" : "rec")
            active: Rec.busy
            onClicked: { if (!Rec.busy) page.closeRequested(); Rec.toggle("region") }
        }
    }

    SectionLabel { text: "desktop" }

    RowLayout {
        Layout.fillWidth: true
        spacing: 6
        IconBtn {
            Layout.fillWidth: true
            icon: Theme.iImage
            label: "wallpaper"
            onClicked: page.overlayRequested("wall")
        }
        IconBtn {
            Layout.fillWidth: true
            icon: Theme.iShuffle
            label: "random"
            onClicked: Wall.random()
        }
        IconBtn {
            Layout.fillWidth: true
            icon: Theme.iWindow
            label: "overview"
            onClicked: page.overlayRequested("overview")
        }
        IconBtn {
            Layout.fillWidth: true
            visible: Clip.available
            icon: Theme.iClipboard
            label: "clipboard"
            onClicked: page.overlayRequested("clip")
        }
    }

    SectionLabel { text: "capture" }

    RowLayout {
        Layout.fillWidth: true
        spacing: 6
        IconBtn {   // where the shot goes: clipboard or ~/pix/ss
            Layout.fillWidth: true
            icon: Shot.save ? Theme.iSave : Theme.iClipboard
            label: Shot.save ? "save" : "copy"
            active: true
            onClicked: Shot.save = !Shot.save
        }
        IconBtn {
            Layout.fillWidth: true
            icon: Theme.iCrop
            label: "area"
            onClicked: { page.closeRequested(); Shot.take("region") }
        }
        IconBtn {
            Layout.fillWidth: true
            icon: Theme.iWindow
            label: "window"
            onClicked: { page.closeRequested(); Shot.take("window") }
        }
        IconBtn {
            Layout.fillWidth: true
            icon: Theme.iMonitor
            label: "screen"
            onClicked: { page.closeRequested(); Shot.take("output") }
        }
        IconBtn {
            Layout.fillWidth: true
            icon: Theme.iSearch
            label: "ocr"
            onClicked: { page.closeRequested(); Shot.take("ocr") }
        }
    }

    Item { Layout.fillHeight: true }

    SectionLabel { text: "session" }

    RowLayout {
        Layout.fillWidth: true
        spacing: 6
        IconBtn {
            Layout.fillWidth: true
            icon: Theme.iLock
            onClicked: page.act("lock", function () { Quickshell.execDetached(["loginctl", "lock-session"]) }, false)
        }
        IconBtn {
            Layout.fillWidth: true
            icon: Theme.iSleep
            onClicked: page.act("sleep", function () { Quickshell.execDetached(["systemctl", "suspend"]) }, false)
        }
        IconBtn {
            Layout.fillWidth: true
            icon: Theme.iLogout
            label: page.armed === "logout" ? "sure?" : ""
            active: page.armed === "logout"
            onClicked: page.act("logout", function () { Hypr.logout() }, true)
        }
        IconBtn {
            Layout.fillWidth: true
            icon: Theme.iReboot
            label: page.armed === "reboot" ? "sure?" : ""
            active: page.armed === "reboot"
            onClicked: page.act("reboot", function () { Quickshell.execDetached(["systemctl", "reboot"]) }, true)
        }
        IconBtn {
            Layout.fillWidth: true
            icon: Theme.iPower
            label: page.armed === "off" ? "sure?" : ""
            active: page.armed === "off"
            onClicked: page.act("off", function () { Quickshell.execDetached(["systemctl", "poweroff"]) }, true)
        }
    }
}
