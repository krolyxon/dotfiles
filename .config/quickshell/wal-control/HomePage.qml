import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Pipewire

ColumnLayout {
    id: page
    spacing: 12
    signal closeRequested()

    property string armed: ""
    Timer { id: disarm; interval: 3000; onTriggered: page.armed = "" }

    function act(name, cmd, confirm) {
        if (confirm && armed !== name) { armed = name; disarm.restart(); return }
        armed = ""
        Quickshell.execDetached(cmd)
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

    Item { Layout.fillHeight: true }

    SectionLabel { text: "session" }

    RowLayout {
        Layout.fillWidth: true
        spacing: 6
        IconBtn {
            Layout.fillWidth: true
            icon: Theme.iLock
            onClicked: page.act("lock", ["loginctl", "lock-session"], false)
        }
        IconBtn {
            Layout.fillWidth: true
            icon: Theme.iSleep
            onClicked: page.act("sleep", ["systemctl", "suspend"], false)
        }
        IconBtn {
            Layout.fillWidth: true
            icon: Theme.iLogout
            label: page.armed === "logout" ? "sure?" : ""
            active: page.armed === "logout"
            onClicked: page.act("logout", ["hyprctl", "dispatch", "exit"], true)
        }
        IconBtn {
            Layout.fillWidth: true
            icon: Theme.iReboot
            label: page.armed === "reboot" ? "sure?" : ""
            active: page.armed === "reboot"
            onClicked: page.act("reboot", ["systemctl", "reboot"], true)
        }
        IconBtn {
            Layout.fillWidth: true
            icon: Theme.iPower
            label: page.armed === "off" ? "sure?" : ""
            active: page.armed === "off"
            onClicked: page.act("off", ["systemctl", "poweroff"], true)
        }
    }
}
