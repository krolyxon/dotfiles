import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland

// Autohide dock (per monitor): touch the bottom edge to slide it up.
// Pinned apps (Settings.dockPinned) + apps with windows on this monitor's workspaces.
// Left click: focus (cycles through that app's windows) or launch. Middle: new instance. Right: pin/unpin.
PanelWindow {
    id: win
    required property var modelData
    screen: modelData
    visible: Settings.dock

    readonly property var hmon: Hyprland.monitorFor(modelData)
    readonly property int size: 40
    property bool shown: false

    anchors.bottom: true
    implicitWidth: Math.max(160, row.implicitWidth + 16)
    implicitHeight: size + 16
    exclusiveZone: 0
    color: "transparent"
    // hidden: only a 2px strip at the very bottom catches the mouse; shown: the whole dock
    mask: Region { item: win.shown ? panel : strip }
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "aurora-dock"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    Timer { id: hide; interval: 600; onTriggered: win.shown = false }

    function appId(t) {
        if (t.wayland && t.wayland.appId) return t.wayland.appId
        return t.lastIpcObject && t.lastIpcObject.class ? t.lastIpcObject.class : ""
    }
    function entryFor(id) {
        return DesktopEntries.byId(id) || DesktopEntries.heuristicLookup(id)
    }
    // [{id, entry, wins: [HyprlandToplevel]}], pinned first (in pin order), then running by first seen
    readonly property var apps: {
        var out = [], byId = {}, pins = Settings.dockPinned
        for (var i = 0; i < pins.length; i++) {
            var p = { id: pins[i], entry: entryFor(pins[i]), wins: [], pinned: true }
            byId[pins[i].toLowerCase()] = p
            out.push(p)
        }
        var l = Hyprland.toplevels.values
        for (var j = 0; j < l.length; j++) {
            var t = l[j]
            if (!t.workspace || !t.workspace.monitor || t.workspace.monitor !== hmon) continue
            var id = appId(t)
            if (id === "") continue
            var e = entryFor(id)
            // match pins by id, or by the desktop entry they resolve to (e.g. "footclient" -> foot)
            var key = id.toLowerCase()
            var a = byId[key]
            if (!a && e) for (var k = 0; k < out.length; k++) if (out[k].entry === e) { a = out[k]; break }
            if (!a) {
                a = { id: id, entry: e, wins: [], pinned: false }
                byId[key] = a
                out.push(a)
            }
            a.wins.push(t)
        }
        return out
    }

    function activate(a) {
        if (a.wins.length === 0) { if (a.entry) Session.launch(a.entry.command, a.entry.workingDirectory); return }
        // focus the next window of that app after the active one (cycles)
        var act = Hyprland.activeToplevel, i = -1
        for (var k = 0; k < a.wins.length; k++) if (act && a.wins[k].address === act.address) i = k
        Hypr.focusWindow(a.wins[(i + 1) % a.wins.length].address)
    }

    Item {
        id: strip
        anchors.bottom: parent.bottom
        width: parent.width
        height: 2
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        onEntered: { hide.stop(); win.shown = true }
        onExited: hide.restart()

        Rectangle {
            id: panel
            width: parent.width
            height: parent.height - 6
            y: win.shown ? 0 : parent.height
            Behavior on y { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
            color: Theme.bgA
            border.width: 1
            border.color: Theme.accent

            Row {
                id: row
                anchors.centerIn: parent
                spacing: 4

                Repeater {
                    model: win.apps
                    delegate: Item {
                        id: cell
                        required property var modelData
                        readonly property bool running: modelData.wins.length > 0
                        readonly property bool focused: {
                            var act = Hyprland.activeToplevel
                            if (!act) return false
                            for (var k = 0; k < modelData.wins.length; k++)
                                if (modelData.wins[k].address === act.address) return true
                            return false
                        }
                        width: win.size
                        height: win.size

                        Rectangle {
                            anchors.fill: parent
                            color: cell.focused ? Theme.accentDim : (cm.containsMouse ? Theme.surfaceHi : "transparent")
                        }
                        Image {
                            id: ico
                            anchors.centerIn: parent
                            width: win.size - 12
                            height: width
                            sourceSize.width: 64
                            sourceSize.height: 64
                            asynchronous: true
                            source: Quickshell.iconPath(cell.modelData.entry ? cell.modelData.entry.icon : cell.modelData.id.toLowerCase(), true)
                        }
                        Text {   // icon not in the theme: first letter of the app name
                            anchors.centerIn: parent
                            visible: ico.status !== Image.Ready
                            text: (cell.modelData.entry ? cell.modelData.entry.name : cell.modelData.id).charAt(0).toUpperCase()
                            color: Theme.accent
                            font.family: Theme.font
                            font.pixelSize: 18
                            font.bold: true
                        }
                        Rectangle {   // running marker: accent underline, wider with more windows
                            visible: cell.running
                            anchors.bottom: parent.bottom
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: Math.min(parent.width - 8, 8 + (cell.modelData.wins.length - 1) * 8)
                            height: 2
                            color: Theme.accent
                        }
                        Rectangle {   // pinned marker: small dot top-right
                            visible: cell.modelData.pinned
                            anchors.top: parent.top
                            anchors.right: parent.right
                            anchors.margins: 3
                            width: 3
                            height: 3
                            color: Theme.dim
                        }
                        MouseArea {
                            id: cm
                            anchors.fill: parent
                            hoverEnabled: true
                            acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
                            cursorShape: Qt.PointingHandCursor
                            onEntered: { hide.stop(); win.shown = true }
                            onClicked: m => {
                                if (m.button === Qt.RightButton) Settings.togglePin(cell.modelData.id)
                                else if (m.button === Qt.MiddleButton) { if (cell.modelData.entry) Session.launch(cell.modelData.entry.command, cell.modelData.entry.workingDirectory) }
                                else win.activate(cell.modelData)
                            }
                        }
                    }
                }
            }
        }
    }
}
