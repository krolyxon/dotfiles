import QtQuick
import Quickshell.Hyprland

// Workspaces 1-10 always shown (like a persistent waybar setup), extras appear when used.
Row {
    id: ws
    spacing: 0

    function find(id) {
        var l = Hyprland.workspaces.values
        for (var i = 0; i < l.length; i++) if (l[i].id === id) return l[i]
        return null
    }
    function ids() {
        var out = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
        var l = Hyprland.workspaces.values
        for (var i = 0; i < l.length; i++) if (l[i].id > 10) out.push(l[i].id)
        out.sort(function (a, b) { return a - b })
        return out
    }
    readonly property var list: ids()

    Repeater {
        model: ws.list
        delegate: Item {
            id: b
            required property var modelData
            readonly property var obj: ws.find(modelData)
            readonly property bool active: Hyprland.focusedWorkspace !== null && Hyprland.focusedWorkspace.id === modelData
            readonly property bool occupied: obj !== null && obj.toplevels.values.length > 0
            readonly property bool urgent: obj !== null && obj.urgent
            readonly property bool lit: active || m.containsMouse

            width: 30
            height: ws.height

            Rectangle {
                anchors.fill: parent
                color: b.lit ? Theme.accent : "transparent"
            }
            Rectangle {   // occupied marker, like the inset underline in your css
                visible: b.occupied && !b.lit
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: 1
                color: Theme.cursorC
            }
            Text {
                anchors.centerIn: parent
                text: Theme.wsIcon(b.modelData)
                color: b.lit ? Theme.bg : (b.urgent ? Theme.err : Theme.fg)
                opacity: (b.occupied || b.lit || b.urgent) ? 1 : 0.4
                font.family: Theme.font
                font.pixelSize: Theme.fontSize + 1
            }
            MouseArea {
                id: m
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: Hypr.workspace(b.modelData)
                onWheel: w => Hypr.workspace(w.angleDelta.y > 0 ? "e-1" : "e+1")
            }
        }
    }
}
