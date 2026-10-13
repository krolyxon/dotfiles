import QtQuick
import Quickshell.Hyprland

// Per-monitor workspaces, dwm / split-monitor-workspaces style.
// Each monitor owns a block of 10 ids (monitor 1: 1-10, monitor 2: 11-20, ...).
// The block is derived from the monitor's own active workspace, so it works with or
// without the plugin. Icons repeat every 10, like your waybar format-icons.
Row {
    id: ws
    spacing: 0

    property var monitor: null           // HyprlandMonitor of the bar this sits in

    readonly property var activeWs: monitor ? monitor.activeWorkspace : null
    readonly property int offset: activeWs && activeWs.id > 0 ? Math.floor((activeWs.id - 1) / 10) * 10 : 0
    readonly property bool monFocused: monitor ? monitor.focused : true
    readonly property var list: [1, 2, 3, 4, 5, 6, 7, 8, 9, 10].map(function (i) { return offset + i })

    function find(id) {
        var l = Hyprland.workspaces.values
        for (var i = 0; i < l.length; i++) if (l[i].id === id) return l[i]
        return null
    }

    // scroll: next/previous *existing* workspace inside this monitor's block (like e+1 / e-1)
    function step(dir) {
        var cur = activeWs ? activeWs.id : offset + 1
        for (var id = cur + dir; id >= offset + 1 && id <= offset + 10; id += dir) {
            var o = find(id)
            if (o !== null && o.toplevels.values.length > 0) { Hypr.workspace(id); return }
        }
    }

    Repeater {
        model: ws.list
        delegate: Item {
            id: b
            required property var modelData
            readonly property var obj: ws.find(modelData)
            readonly property bool active: ws.activeWs !== null && ws.activeWs.id === modelData
            readonly property bool occupied: obj !== null && obj.toplevels.values.length > 0
            readonly property bool urgent: obj !== null && obj.urgent
            // active on the focused monitor = filled; active on another monitor = accent text + thick underline
            readonly property bool lit: (active && ws.monFocused) || m.containsMouse
            readonly property bool dimActive: active && !ws.monFocused && !m.containsMouse

            width: 30
            height: ws.height

            Rectangle {
                anchors.fill: parent
                color: b.lit ? Theme.accent : "transparent"
            }
            Rectangle {   // occupied marker (1px), or active-on-unfocused-monitor marker (2px)
                visible: (b.occupied && !b.lit) || b.dimActive
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: b.dimActive ? 2 : 1
                color: b.dimActive ? Theme.accent : Theme.cursorC
            }
            Text {
                anchors.centerIn: parent
                text: Theme.wsIcon(b.modelData)
                color: b.lit ? Theme.bg : (b.dimActive ? Theme.accent : (b.urgent ? Theme.err : Theme.fg))
                opacity: (b.occupied || b.active || b.lit || b.urgent) ? 1 : 0.4
                font.family: Theme.font
                font.pixelSize: Theme.wsFontSize
            }
            MouseArea {
                id: m
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: Hypr.workspace(b.modelData)
                onWheel: w => ws.step(w.angleDelta.y > 0 ? -1 : 1)
            }
        }
    }
}
