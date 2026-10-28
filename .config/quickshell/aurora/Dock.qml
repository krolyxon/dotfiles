import QtQuick
import QtQuick.Effects
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
    readonly property int size: 48
    property bool shown: false

    anchors.bottom: true
    implicitWidth: Math.max(160, row.implicitWidth + 28)
    implicitHeight: size + 30
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

        // a pill of round icons; running apps get dots under them (one per window, up to 3)
        Rectangle {
            id: panel
            width: parent.width
            height: parent.height - 8
            y: win.shown ? 0 : parent.height
            Behavior on y { enabled: Theme.motion; NumberAnimation { duration: Theme.t; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.glide } }
            radius: height / 2
            color: Theme.fade(Theme.s1, Theme.panelAlpha)
            border.width: 1
            border.color: Theme.s2

            Row {
                id: row
                anchors.centerIn: parent
                spacing: 8

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
                            anchors.margins: 2
                            radius: width / 2
                            color: cell.focused ? Theme.fill : (cm.containsMouse ? Theme.s3 : Theme.s2)
                        }
                        Image {
                            id: ico
                            anchors.centerIn: parent
                            width: win.size - 20
                            height: width
                            sourceSize.width: 64
                            sourceSize.height: 64
                            asynchronous: true
                            source: Quickshell.iconPath(cell.modelData.entry ? cell.modelData.entry.icon : cell.modelData.id.toLowerCase(), true)
                            layer.enabled: Settings.appIcons !== "colour"
                            layer.effect: Settings.appIcons === "mono" ? monoFx : dotFx
                            Component { id: dotFx; DotMask { step: 2.5 } }
                            Component { id: monoFx; MultiEffect { saturation: -1 } }
                        }
                        Text {   // icon not in the theme: first letter of the app name
                            anchors.centerIn: parent
                            visible: ico.status !== Image.Ready
                            text: (cell.modelData.entry ? cell.modelData.entry.name : cell.modelData.id).charAt(0).toUpperCase()
                            color: cell.focused ? Theme.fillFg : Theme.fg
                            font.family: Theme.dot
                            font.pixelSize: 26
                            font.weight: Font.Black
                        }
                        Row {   // running: a dot per window (up to 3) under the icon
                            visible: cell.running
                            anchors.top: parent.bottom
                            anchors.topMargin: 3
                            anchors.horizontalCenter: parent.horizontalCenter
                            spacing: 3
                            Repeater {
                                model: Math.min(3, cell.modelData.wins.length)
                                Rectangle { width: 4; height: 4; radius: 2; color: cell.focused ? Theme.fill : Theme.grey }
                            }
                        }
                        Rectangle {   // pinned marker: small dot top-right
                            visible: cell.modelData.pinned && !cell.running
                            anchors.top: parent.top
                            anchors.right: parent.right
                            anchors.margins: 2
                            width: 5
                            height: 5
                            radius: 2.5
                            color: Theme.mute
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
