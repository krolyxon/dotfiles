import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland

PanelWindow {
    id: win
    property bool opened: false
    property int tab: 0
    signal tabRequested(int index)
    signal closeRequested()

    visible: opened
    anchors { top: true; right: true }
    margins { top: 6; right: 8 }          // sits just under the bar (bar's exclusive zone is respected)
    implicitWidth: 440
    implicitHeight: 640
    exclusiveZone: 0
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "aurora-panel"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

    // click anywhere outside to close
    HyprlandFocusGrab {
        windows: [win]
        active: win.opened
        onCleared: win.closeRequested()
    }

    readonly property var tabs: [
        { icon: Theme.iHome, name: "home" },
        { icon: Theme.iVolHigh, name: "audio" },
        { icon: Theme.iWifi, name: "net" },
        { icon: Theme.iBt, name: "bt" },
        { icon: Theme.iChip, name: "system" },
        { icon: Theme.iBell, name: "notifs" }
    ]

    Rectangle {
        anchors.fill: parent
        color: Theme.bgA
        border.width: 2
        border.color: Theme.accent
        focus: true
        Keys.onEscapePressed: win.closeRequested()

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 10

            RowLayout {
                Layout.fillWidth: true
                spacing: 2

                Repeater {
                    model: win.tabs
                    delegate: Rectangle {
                        id: tabBtn
                        required property var modelData
                        required property int index
                        readonly property bool current: win.tab === index
                        implicitWidth: lbl.implicitWidth + 22
                        implicitHeight: 28
                        color: current ? Theme.accent : (tm.containsMouse ? Theme.surfaceHi : "transparent")

                        Text {
                            id: lbl
                            anchors.centerIn: parent
                            text: tabBtn.current ? tabBtn.modelData.icon + "  " + tabBtn.modelData.name : tabBtn.modelData.icon
                            color: tabBtn.current ? Theme.bg : Theme.fg
                            font.family: Theme.font
                            font.pixelSize: Theme.fontSize
                            font.bold: true
                        }
                        Rectangle {   // unread badge on the notifs tab
                            visible: tabBtn.modelData.name === "notifs" && Notifs.count > 0 && !tabBtn.current
                            width: 6; height: 6
                            anchors.top: parent.top
                            anchors.right: parent.right
                            anchors.margins: 3
                            color: Theme.accent
                        }
                        MouseArea {
                            id: tm
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: win.tabRequested(tabBtn.index)
                        }
                    }
                }
                Item { Layout.fillWidth: true }
                IconBtn { icon: Theme.iClose; implicitHeight: 28; onClicked: win.closeRequested() }
            }

            Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Theme.line }

            StackLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                currentIndex: win.tab

                HomePage { onCloseRequested: win.closeRequested() }
                AudioPage {}
                NetPage { active: win.opened && win.tab === 2 }
                BtPage { active: win.opened && win.tab === 3 }
                SysPage {}
                NotifPage {}
            }
        }
    }
}
