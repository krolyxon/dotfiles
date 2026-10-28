import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland

// The desktop backdrop of one monitor (Background layer, under the home screen): the wallpaper in Settings.wallLook
// (WallView), and without one a dot grid with the breathing halftone orb. A window of its own: the home screen above it
// redraws often (clock colon, rings, cava) while this full-screen shader only redraws for the wave or a look change.
// aurora draws the wallpaper itself; hyprpaper isn't used any more (Wall.qml).
// After glyph-rice (github.com/Nebelung-cloud/glyph-rice, GPL-3.0), home/Back.qml.
PanelWindow {
    id: win
    required property var modelData
    screen: modelData

    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    color: Theme.bg
    mask: Region {}
    WlrLayershell.layer: WlrLayer.Background
    WlrLayershell.namespace: "aurora-back"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    readonly property var hmon: Hyprland.monitorFor(modelData)
    readonly property bool home: hmon && hmon.activeWorkspace ? hmon.activeWorkspace.toplevels.values.length === 0 : true

    property real phase: 0
    Timer { running: win.home && orb.visible; interval: 100; repeat: true; onTriggered: win.phase += 0.1 }

    Image {
        visible: Settings.dotGrid && !wall.opaque
        anchors.fill: parent
        fillMode: Image.Tile
        source: "data:image/svg+xml," + encodeURIComponent('<svg xmlns="http://www.w3.org/2000/svg" width="32" height="32"><circle cx="16" cy="16" r="1.5" fill="#' + Theme.hex(Theme.s2) + '"/></svg>')
    }
    Orb {
        id: orb
        visible: !wall.opaque
        x: win.width - 720
        y: win.height - 580
        phase: win.phase
    }
    WallView {
        id: wall
        anchors.fill: parent
        path: Wall.current
    }
}
