import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Services.Pipewire

ShellRoot {
    id: root
    property bool opened: false
    property int tab: 0
    readonly property var tabNames: ["home", "audio", "net", "bt"]

    function openTab(name) {
        var i = tabNames.indexOf(name)
        if (i >= 0) tab = i
        opened = true
    }

    // keep every pipewire node bound so volume / mute / properties are readable
    PwObjectTracker { objects: Pipewire.nodes.values }

    PanelWindow {
        id: panel
        visible: root.opened
        anchors { top: true; right: true }
        margins { top: 2 ; right: 2 }
        implicitWidth: 430
        implicitHeight: 590
        exclusiveZone: 0
        color: "transparent"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "wal-control"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

        Rectangle {
            anchors.fill: parent
            color: Theme.bgA
            border.width: 2
            border.color: Theme.accent
            focus: true
            Keys.onEscapePressed: root.opened = false

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 10

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 2
                    Repeater {
                        model: [
                            { icon: Theme.iHome, name: "home" },
                            { icon: Theme.iVolHigh, name: "audio" },
                            { icon: Theme.iWifi, name: "net" },
                            { icon: Theme.iBt, name: "bt" }
                        ]
                        delegate: Rectangle {
                            id: tabBtn
                            required property var modelData
                            required property int index
                            implicitWidth: lbl.implicitWidth + 22
                            implicitHeight: 28
                            color: root.tab === index ? Theme.accent : (tm.containsMouse ? Theme.surfaceHi : "transparent")
                            Text {
                                id: lbl
                                anchors.centerIn: parent
                                text: tabBtn.modelData.icon + "  " + tabBtn.modelData.name
                                color: root.tab === tabBtn.index ? Theme.bg : Theme.fg
                                font.family: Theme.font
                                font.pixelSize: Theme.fontSize
                            }
                            MouseArea {
                                id: tm
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.tab = tabBtn.index
                            }
                        }
                    }
                    Item { Layout.fillWidth: true }
                    IconBtn { icon: Theme.iClose; height: 28; onClicked: root.opened = false }
                }

                Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Theme.line }

                StackLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    currentIndex: root.tab

                    HomePage { onCloseRequested: root.opened = false }
                    AudioPage {}
                    NetPage { active: root.opened && root.tab === 2 }
                    BtPage { active: root.opened && root.tab === 3 }
                }
            }
        }
    }

    // clicking anywhere outside the panel closes it
    HyprlandFocusGrab {
        windows: [panel]
        active: root.opened
        onCleared: root.opened = false
    }

    IpcHandler {
        target: "control"
        function toggle(): void { root.opened = !root.opened }
        function open(): void { root.opened = true }
        function close(): void { root.opened = false }
        function show(name: string): void { root.openTab(name) }
    }
}
