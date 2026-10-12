import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: win
    property bool suppressed: false      // hidden while the control panel is open

    visible: Notifs.popups.length > 0 && !suppressed
    anchors { top: true; right: true }
    margins { top: 6; right: 8 }
    implicitWidth: 360
    implicitHeight: col.implicitHeight
    exclusiveZone: 0
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "aurora-notifs"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    ColumnLayout {
        id: col
        width: 360
        spacing: 6
        Repeater {
            model: Notifs.popups
            delegate: NotifCard {
                required property var modelData
                n: modelData.n
                popup: true
            }
        }
    }
}
