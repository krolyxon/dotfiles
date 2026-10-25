import QtQuick
import QtQuick.Layouts

// Settings app > Shell: desktop widgets, dock, OSD, notifications.
Flickable {
    id: flick
    clip: true
    contentWidth: width
    contentHeight: col.implicitHeight
    boundsBehavior: Flickable.StopAtBounds

    ColumnLayout {
        id: col
        width: flick.width
        spacing: 8

        SectionLabel { text: "desktop" }
        Switch { label: "clock"; hint: "big clock + stats on the wallpaper"; checked: Settings.desktopClock; onToggled: on => Settings.desktopClock = on }
        Switch { label: "visualizer"; hint: "cava bars while music plays"; checked: Settings.desktopViz; onToggled: on => Settings.desktopViz = on }
        Knob { label: "visualizer bars"; from: 16; to: 128; value: Settings.vizBars; onMoved: v => Settings.vizBars = v }

        SectionLabel { text: "dock" }
        Switch { label: "dock"; hint: "autohides at the bottom edge"; checked: Settings.dock; onToggled: on => Settings.dock = on }
        Text {
            text: "pinned apps (pin more from the dock's right-click)"
            color: Theme.dim
            font.family: Theme.font
            font.pixelSize: Theme.fontSize - 1
        }
        Flow {
            Layout.fillWidth: true
            spacing: 4
            Repeater {
                model: Settings.dockPinned
                delegate: IconBtn {
                    required property string modelData
                    implicitHeight: 26
                    icon: Theme.iClose
                    iconSize: 11
                    label: modelData
                    onClicked: Settings.togglePin(modelData)
                }
            }
        }

        SectionLabel { text: "on-screen display" }
        Knob { label: "osd timeout"; unit: "ms"; from: 500; to: 4000; value: Settings.osdTimeout; onMoved: v => Settings.osdTimeout = Math.round(v / 100) * 100 }

        SectionLabel { text: "network" }
        Switch { label: "captive portals"; hint: "open the login page in the browser when a network needs one"; checked: Settings.portalAutoOpen; onToggled: on => Settings.portalAutoOpen = on }

        SectionLabel { text: "bar" }
        Switch { label: "privacy indicators"; hint: "show in the bar when an app records the mic, uses the camera or shares the screen"; checked: Settings.privacyIndicators; onToggled: on => Settings.privacyIndicators = on }

        SectionLabel { text: "notifications" }
        Switch { label: "do not disturb"; hint: "hide popups and mute the sound (critical ones still show)"; checked: Notifs.dnd; onToggled: on => Notifs.dnd = on }
        Switch { label: "sound"; checked: Settings.notifSound; onToggled: on => Settings.notifSound = on }
        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            Knob { label: "sound volume"; from: 0; to: 1; decimals: 2; value: Settings.notifVolume; onMoved: v => Settings.notifVolume = v }
            IconBtn { icon: Theme.iPlay; implicitHeight: 26; onClicked: Notifs.playSound() }
        }

        Item { Layout.preferredHeight: 6 }
        RowLayout {
            Layout.fillWidth: true
            Text {
                Layout.fillWidth: true
                text: "~/.config/aurora/settings.json"
                elide: Text.ElideLeft
                color: Theme.dim
                font.family: Theme.font
                font.pixelSize: Theme.fontSize - 2
            }
            IconBtn { icon: Theme.iRefresh; label: "reset shell settings"; onClicked: Settings.reset() }
        }
    }
}
