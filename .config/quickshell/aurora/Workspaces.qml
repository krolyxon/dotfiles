import QtQuick
import Quickshell.Hyprland

// This monitor's 10 workspaces as dots (split-monitor-workspaces: monitor 1 owns 1-10, monitor 2 11-20, ...; the block
// comes from the monitor's own active workspace, so it works without the plugin too).
// A row, or a column in the vertical bar. Active = a long pill (primary on the focused monitor, grey on the others),
// occupied = grey dot, empty = dim dot,
// urgent = the live colour. Click = go there, wheel = the next / previous occupied one.
// After glyph-rice (github.com/Nebelung-cloud/glyph-rice, GPL-3.0), bar/Bar.qml.
Grid {
    id: ws
    spacing: 6
    columns: vertical ? 1 : list.length   // only columns flips, see BarPill

    property var monitor: null           // HyprlandMonitor of the bar this sits in
    property bool vertical: Theme.barVertical
    property real thick: Theme.barSize   // each dot's cell across the bar (its click area)

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

            width: ws.vertical ? ws.thick : dot.width
            height: ws.vertical ? dot.height : ws.thick

            Rectangle {
                id: dot
                anchors.centerIn: parent
                width: b.active && !ws.vertical ? 26 : 8
                height: b.active && ws.vertical ? 26 : 8
                radius: 4
                color: b.urgent && !b.active ? Theme.live
                       : b.active ? (ws.monFocused ? Theme.fill : Theme.grey)
                       : m.containsMouse ? Theme.fg
                       : b.occupied ? Theme.grey : Theme.s3
                Behavior on width {
                    enabled: Theme.motion
                    NumberAnimation { duration: Theme.t; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.glide }
                }
                Behavior on height {
                    enabled: Theme.motion
                    NumberAnimation { duration: Theme.t; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.glide }
                }
                Behavior on color { enabled: Theme.motion; ColorAnimation { duration: Theme.t } }
            }
            MouseArea {
                id: m
                anchors.fill: parent
                anchors.leftMargin: ws.vertical ? 0 : -3
                anchors.rightMargin: ws.vertical ? 0 : -3
                anchors.topMargin: ws.vertical ? -3 : 0
                anchors.bottomMargin: ws.vertical ? -3 : 0
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: Hypr.workspace(b.modelData)
                onWheel: w => ws.step(w.angleDelta.y > 0 ? -1 : 1)
            }
        }
    }
}
