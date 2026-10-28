import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland

// Window overview for one monitor: its 10 workspaces as scaled boxes with live window previews.
// Click a window = focus, click a workspace = switch, drag a window onto another box = move.
// Type to filter by title/class, Enter focuses the first match, Esc closes.
PanelWindow {
    id: win
    property bool opened: false
    signal closeRequested()

    visible: opened
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "aurora-overview"
    WlrLayershell.keyboardFocus: opened ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    readonly property var mon: screen ? Hyprland.monitorFor(screen) : null
    readonly property var activeWs: mon ? mon.activeWorkspace : null
    // same 10-per-monitor block as Workspaces.qml (split-monitor-workspaces)
    readonly property int offset: activeWs && activeWs.id > 0 ? Math.floor((activeWs.id - 1) / 10) * 10 : 0
    readonly property real monW: mon ? mon.width / mon.scale : 1920
    readonly property real monH: mon ? mon.height / mon.scale : 1080

    onOpenedChanged: {
        if (!opened) return
        filter.text = ""
        Hyprland.refreshToplevels()
        Hyprland.refreshMonitors()
        filter.forceActiveFocus()
    }

    function windowsOn(id) {
        var l = Hyprland.toplevels.values, out = []
        for (var i = 0; i < l.length; i++) if (l[i].workspace && l[i].workspace.id === id) out.push(l[i])
        return out
    }
    function cls(t) { return t.lastIpcObject && t.lastIpcObject.class ? t.lastIpcObject.class : "" }
    function matches(t) {
        var q = filter.text.toLowerCase()
        return q === "" || String(t.title).toLowerCase().indexOf(q) >= 0 || cls(t).toLowerCase().indexOf(q) >= 0
    }
    function firstMatch() {
        for (var i = 1; i <= 10; i++) {
            var l = windowsOn(offset + i)
            for (var j = 0; j < l.length; j++) if (matches(l[j])) return l[j]
        }
        return null
    }
    function iconFor(t) {
        var e = DesktopEntries.heuristicLookup(cls(t))
        return Quickshell.iconPath(e ? e.icon : cls(t).toLowerCase(), true)
    }
    property int dragWs: -1               // box whose window is being dragged (raised above the others)
    Timer { id: resync; interval: 300; onTriggered: Hyprland.refreshToplevels() }

    function focus(t) { Hypr.focusWindow(t.address); closeRequested() }

    // box under a point in grid coordinates (for drops)
    function wsAt(px, py) {
        for (var i = 0; i < boxes.count; i++) {
            var b = boxes.itemAt(i)
            var p = b.mapFromItem(grid, px, py)
            if (p.x >= 0 && p.y >= 0 && p.x <= b.width && p.y <= b.height) return b.wsId
        }
        return -1
    }

    Rectangle {
        anchors.fill: parent
        color: Theme.scrim
        MouseArea { anchors.fill: parent; onClicked: win.closeRequested() }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 40
        anchors.topMargin: Theme.barHeight + 24
        spacing: 16

        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: 8
            Rectangle {
                implicitWidth: 520
                implicitHeight: 56
                radius: 28
                color: Theme.s2
                Icon {
                    id: lens
                    x: 20
                    anchors.verticalCenter: parent.verticalCenter
                    text: Theme.iSearch
                    color: Theme.grey
                    font.pixelSize: 19
                }
                Text {
                    anchors.left: filter.left
                    anchors.verticalCenter: parent.verticalCenter
                    visible: filter.text === ""
                    text: "Filter windows"
                    color: Theme.mute
                    font: filter.font
                }
                TextInput {
                    id: filter
                    anchors.left: lens.right
                    anchors.leftMargin: 14
                    anchors.right: parent.right
                    anchors.rightMargin: 20
                    anchors.verticalCenter: parent.verticalCenter
                    color: Theme.fg
                    selectionColor: Theme.fill
                    selectedTextColor: Theme.fillFg
                    font.family: Theme.ui
                    font.pixelSize: 18
                    clip: true
                    cursorDelegate: Rectangle {
                        width: 2
                        color: Theme.live
                        visible: filter.activeFocus
                        Timer { running: filter.activeFocus; interval: 500; repeat: true; onTriggered: parent.opacity = 1 - parent.opacity }
                    }
                    Keys.onEscapePressed: win.closeRequested()
                    Keys.onReturnPressed: { var t = win.firstMatch(); if (t) win.focus(t) }
                    Keys.onEnterPressed: { var t = win.firstMatch(); if (t) win.focus(t) }
                }
            }
            Row {
                Layout.leftMargin: 18
                spacing: 28
                Repeater {
                    model: ["click focus", "drag move", "↵ first match", "esc close"]
                    Lb { required property string modelData; text: modelData }
                }
            }
        }

        Item {
            id: grid
            Layout.fillWidth: true
            Layout.fillHeight: true

            readonly property int cols: 5
            readonly property int gap: 16
            // largest box with the monitor's aspect ratio that fits 5 x 2
            readonly property real boxW: Math.min((width - gap * (cols - 1)) / cols,
                                                  ((height - gap - 2 * 40) / 2) * win.monW / win.monH)
            readonly property real boxH: boxW * win.monH / win.monW
            readonly property real sc: boxW / win.monW

            Repeater {
                id: boxes
                model: 10
                delegate: Item {
                    id: box
                    required property int index
                    readonly property int wsId: win.offset + index + 1
                    readonly property bool current: win.activeWs !== null && win.activeWs.id === wsId
                    readonly property real originX: (grid.width - (grid.boxW * grid.cols + grid.gap * (grid.cols - 1))) / 2
                    x: originX + (index % grid.cols) * (grid.boxW + grid.gap)
                    y: Math.floor(index / grid.cols) * (grid.boxH + grid.gap + 40)
                    width: grid.boxW
                    height: grid.boxH + 40
                    z: win.dragWs === wsId ? 10 : 0

                    Row {
                        x: 6
                        spacing: 10
                        Num {
                            text: box.index + 1
                            font.pixelSize: 28
                            color: box.current ? Theme.fill : Theme.fg
                        }
                        Lb {
                            anchors.verticalCenter: parent.verticalCenter
                            text: win.windowsOn(box.wsId).length ? win.windowsOn(box.wsId).length + " open" : "empty"
                            color: box.current ? Theme.fill : Theme.grey
                        }
                    }

                    Rectangle {
                        id: frame
                        y: 34
                        width: grid.boxW
                        height: grid.boxH
                        radius: 20
                        clip: true
                        color: Theme.s1
                        border.width: box.current ? 2 : 1
                        border.color: box.current ? Theme.fill : (wm.containsMouse ? Theme.grey : Theme.s2)

                        MouseArea {
                            id: wm
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: { Hypr.workspace(box.wsId); win.closeRequested() }
                        }

                        Repeater {
                            model: win.windowsOn(box.wsId)
                            delegate: Rectangle {
                                id: tile
                                required property var modelData
                                readonly property var ipc: modelData.lastIpcObject || {}
                                readonly property var at: ipc.at || [0, 0]
                                readonly property var size: ipc.size || [win.monW / 2, win.monH / 2]
                                readonly property bool hit: win.matches(modelData)
                                readonly property real homeX: (at[0] - (win.mon ? win.mon.x : 0)) * grid.sc
                                readonly property real homeY: (at[1] - (win.mon ? win.mon.y : 0)) * grid.sc
                                x: homeX
                                y: homeY
                                width: Math.max(12, size[0] * grid.sc)
                                height: Math.max(12, size[1] * grid.sc)
                                z: dm.drag.active ? 10 : (ipc.floating ? 2 : 1)
                                color: Theme.s3
                                radius: 6
                                border.width: dm.containsMouse || dm.drag.active ? 2 : 1
                                border.color: dm.containsMouse || dm.drag.active ? Theme.fill : Theme.s2
                                opacity: hit ? 1 : 0.25

                                ScreencopyView {
                                    id: shot
                                    anchors.fill: parent
                                    anchors.margins: 1
                                    captureSource: win.opened && tile.modelData.wayland ? tile.modelData.wayland : null
                                    live: true
                                }
                                Image {   // big centred icon until the preview arrives, then a corner badge
                                    x: shot.hasContent ? 4 : (parent.width - width) / 2
                                    y: shot.hasContent ? parent.height - height - 4 : (parent.height - height) / 2
                                    width: shot.hasContent ? 18 : Math.min(32, parent.width / 2)
                                    height: width
                                    sourceSize.width: 64
                                    sourceSize.height: 64
                                    source: win.iconFor(tile.modelData)
                                    asynchronous: true
                                }
                                MouseArea {
                                    id: dm
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: drag.active ? Qt.ClosedHandCursor : Qt.PointingHandCursor
                                    drag.target: tile
                                    drag.threshold: 6
                                    drag.onActiveChanged: if (drag.active) win.dragWs = box.wsId
                                    onReleased: {
                                        win.dragWs = -1
                                        if (!drag.active) return
                                        var c = tile.mapToItem(grid, tile.width / 2, tile.height / 2)
                                        var ws = win.wsAt(c.x, c.y)
                                        if (ws > 0 && ws !== box.wsId) { Hypr.moveWindow(tile.modelData.address, ws); resync.restart() }
                                        tile.x = Qt.binding(() => tile.homeX)
                                        tile.y = Qt.binding(() => tile.homeY)
                                    }
                                    onClicked: win.focus(tile.modelData)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
