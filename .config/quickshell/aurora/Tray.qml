import QtQuick
import Quickshell
import Quickshell.Services.SystemTray

Item {
    id: tray
    property bool show: true
    visible: show && SystemTray.items.values.length > 0
    implicitWidth: row.implicitWidth + 24
    implicitHeight: parent ? parent.height : Theme.barHeight

    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: 1
        color: Theme.dim
    }
    Row {
        id: row
        anchors.centerIn: parent
        spacing: 10
        Repeater {
            model: SystemTray.items
            delegate: Item {
                id: it
                required property var modelData
                width: 14
                height: 14
                anchors.verticalCenter: parent.verticalCenter

                function openMenu() {
                    var p = it.mapToItem(null, 0, it.height + 4)
                    modelData.display(QsWindow.window, p.x, p.y)
                }
                Image {
                    anchors.fill: parent
                    source: it.modelData.icon
                    sourceSize: Qt.size(28, 28)
                    smooth: true
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
