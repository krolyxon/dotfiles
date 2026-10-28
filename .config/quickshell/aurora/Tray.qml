import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Services.SystemTray

// Tray icons in the bar; monochrome unless Settings.appIcons is "colour" (dots are too coarse at this size).
Item {
    id: tray
    property bool show: true
    visible: show && SystemTray.items.values.length > 0
    implicitWidth: row.implicitWidth + 22
    implicitHeight: parent ? parent.height : Theme.barSize

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 12
        Repeater {
            model: SystemTray.items
            delegate: Item {
                id: it
                required property var modelData
                width: 16
                height: 16
                anchors.verticalCenter: parent.verticalCenter

                function openMenu() {
                    var p = it.mapToItem(null, 0, it.height + 10)
                    modelData.display(QsWindow.window, p.x, p.y)
                }
                Image {
                    anchors.fill: parent
                    source: it.modelData.icon
                    sourceSize: Qt.size(32, 32)
                    smooth: true
                    layer.enabled: Settings.appIcons !== "colour"
                    layer.effect: MultiEffect { saturation: -1; brightness: 0.1 }
                }
                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                    cursorShape: Qt.PointingHandCursor
                    onClicked: mouse => {
                        if (mouse.button === Qt.LeftButton) {
                            if (it.modelData.onlyMenu) it.openMenu()
                            else it.modelData.activate()
                        } else if (mouse.button === Qt.MiddleButton) {
                            it.modelData.secondaryActivate()
                        } else {
                            it.openMenu()
                        }
                    }
                }
            }
        }
    }
}
