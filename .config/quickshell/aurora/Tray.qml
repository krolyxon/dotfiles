import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Services.SystemTray

// Tray icons in the bar (a row, or a column in the vertical bar); monochrome unless Settings.appIcons is "colour"
// (dots are too coarse at this size).
Item {
    id: tray
    property bool show: true
    property bool vertical: Theme.barVertical
    visible: show && SystemTray.items.values.length > 0
    implicitWidth: vertical ? Theme.barSize : row.implicitWidth + 22
    implicitHeight: vertical ? row.implicitHeight + 22 : Theme.barSize

    Grid {
        id: row
        anchors.centerIn: parent
        columns: tray.vertical ? 1 : Math.max(1, rep.count)   // only columns flips, see BarPill
        spacing: 12
        Repeater {
            id: rep
            model: SystemTray.items
            delegate: Item {
                id: it
                required property var modelData
                width: 16
                height: 16

                // under the icon, or beside it in the vertical bar
                function openMenu() {
                    var p = tray.vertical ? it.mapToItem(null, it.width + 14, 0) : it.mapToItem(null, 0, it.height + 10)
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
