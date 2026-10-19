import QtQuick
import QtQuick.Layouts
import Quickshell

// The settings app: a normal Hyprland window (class org.quickshell, title "aurora settings"; floated + sized by a
// window rule). Sidebar of sections, one Loader so only the shown section runs (net scans, bt discovery).
// Esc closes, Ctrl+Tab / Ctrl+Shift+Tab (or Ctrl+J/K) cycle sections. Opened with the `settings [section]` IPC.
FloatingWindow {
    id: win
    property bool opened: false
    property string section: "network"
    signal closeRequested()
    signal sectionRequested(string name)
    signal overlayRequested(string name)

    visible: opened
    title: "aurora settings"
    implicitWidth: 960
    implicitHeight: 680
    color: Theme.bg
    // closed by the compositor (killactive): keep shell state in sync
    onVisibleChanged: if (!visible && opened) closeRequested()

    readonly property var sections: [
        { id: "network",    icon: Theme.iWifi,     name: "network",    group: "connections" },
        { id: "bluetooth",  icon: Theme.iBt,       name: "bluetooth",  group: "connections" },
        { id: "sound",      icon: Theme.iVolHigh,  name: "sound",      group: "connections" },
        { id: "appearance", icon: Theme.iPalette,  name: "appearance", group: "look" },
        { id: "shell",      icon: Theme.iDock,     name: "shell",      group: "look" }
    ]
    readonly property int index: {
        for (var i = 0; i < sections.length; i++) if (sections[i].id === section) return i
        return 0
    }
    function cycle(d) { sectionRequested(sections[(index + d + sections.length) % sections.length].id) }

    Item {
        anchors.fill: parent
        focus: true
        Keys.onPressed: e => {
            var ctrl = e.modifiers & Qt.ControlModifier
            if (e.key === Qt.Key_Escape) { win.closeRequested(); e.accepted = true }
            else if (ctrl && (e.key === Qt.Key_Tab || e.key === Qt.Key_J)) { win.cycle(1); e.accepted = true }
            else if (ctrl && (e.key === Qt.Key_Backtab || e.key === Qt.Key_K)) { win.cycle(-1); e.accepted = true }
        }

        RowLayout {
            anchors.fill: parent
            spacing: 0

            // sidebar
            Rectangle {
                Layout.fillHeight: true
                Layout.preferredWidth: 200
                color: Theme.surface
                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 2
                    Text {
                        Layout.bottomMargin: 8
                        text: Theme.iCog + "  aurora settings"
                        color: Theme.accent
                        font.family: Theme.font
                        font.pixelSize: Theme.fontSize + 1
                        font.bold: true
                    }
                    Repeater {
                        model: win.sections
                        delegate: ColumnLayout {
                            id: entry
                            required property var modelData
                            required property int index
                            readonly property bool current: win.section === modelData.id
                            readonly property bool firstOfGroup: index === 0 || win.sections[index - 1].group !== modelData.group
                            Layout.fillWidth: true
                            spacing: 2
                            Text {
                                visible: entry.firstOfGroup
                                Layout.topMargin: entry.index === 0 ? 0 : 8
                                text: entry.modelData.group.toUpperCase()
                                color: Theme.dim
                                font.family: Theme.font
                                font.pixelSize: Theme.fontSize - 3
                                font.letterSpacing: 1.5
                            }
                            Rectangle {
                                Layout.fillWidth: true
                                implicitHeight: 30
                                color: entry.current ? Theme.accent : (em.containsMouse ? Theme.surfaceHi : "transparent")
                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    x: 10
                                    text: entry.modelData.icon + "   " + entry.modelData.name
                                    color: entry.current ? Theme.bg : Theme.fg
                                    font.family: Theme.font
                                    font.pixelSize: Theme.fontSize
                                    font.bold: entry.current
                                }
                                MouseArea {
                                    id: em
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: win.sectionRequested(entry.modelData.id)
                                }
                            }
                        }
                    }
                    Item { Layout.fillHeight: true }
                }
            }
            Rectangle { Layout.fillHeight: true; Layout.preferredWidth: 1; color: Theme.line }

            // content
            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.margins: 16
                spacing: 12
                Text {
                    text: win.sections[win.index].name.toUpperCase()
                    color: Theme.fg
                    font.family: Theme.font
                    font.pixelSize: Theme.fontSize + 4
                    font.bold: true
                    font.letterSpacing: 2
                }
                Loader {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    active: win.opened
                    sourceComponent: {
                        switch (win.section) {
                        case "bluetooth":  return btC
                        case "sound":      return soundC
                        case "appearance": return appearanceC
                        case "shell":      return shellC
                        default:           return netC
                        }
                    }
                }
            }
        }
    }

    Component { id: netC; NetPage { active: true } }
    Component { id: btC; BtPage { active: true } }
    Component { id: soundC; AudioPage {} }
    Component { id: appearanceC; SetAppearance { onOverlayRequested: name => win.overlayRequested(name) } }
    Component { id: shellC; SetShell {} }
}
