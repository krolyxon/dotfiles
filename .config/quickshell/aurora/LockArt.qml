import QtQuick
import Quickshell
import Quickshell.Io

// hyprlock's pictures (hypr/hyprlock.conf; hyprlock can't draw aurora's dots): the wallpaper exactly as Back draws it
// (any Settings.wallLook) and your face (~/.face, else DotArt's gradient) in a ring of dots, saved as
// ~/.cache/aurora/lock-wall.png / lock-face.png whenever they change. No wallpaper = no lock-wall.png (hyprlock shows $bg).
// One screen's Back holds it: aurora has one wallpaper for every monitor, hyprlock scales it.
Item {
    id: root

    required property WallView view   // Back's (not `wall`: `wall: wall` would bind to itself)
    readonly property string dir: Quickshell.env("HOME") + "/.cache/aurora"

    // everything that changes the pictures; saved once it all settled (the wallpaper wave, the look's blend, colour waves)
    readonly property string key: [view.shown, view.opaque, view.look, view.pitch, view.bright, view.width, view.height,
        Theme.bg, Theme.fg, Theme.fill, Theme.s1, Theme.s3, hasFace].join("|")
    onKeyChanged: settle.restart()
    Timer { id: settle; interval: 2500; onTriggered: root.save() }

    function save() {
        if (view.opaque) view.grabToImage(r => r.saveToFile(dir + "/lock-wall.png"))
        else Quickshell.execDetached(["rm", "-f", dir + "/lock-wall.png"])
        face.grabToImage(r => r.saveToFile(dir + "/lock-face.png"))
    }

    property bool hasFace: false   // checked first: a missing ~/.face would only warn in DotArt
    FileView {
        path: Quickshell.env("HOME") + "/.face"
        printErrors: false
        onLoaded: root.hasFace = true
        onLoadFailed: root.hasFace = false
    }

    // the avatar as glyph's lock screen draws it; off-screen, only ever grabbed
    Item {
        id: face
        x: -width - 100
        width: 104
        height: 104
        Ring { anchors.fill: parent; anchors.margins: 4; n: 32; dot: 5 }
        DotArt {
            anchors.fill: parent
            anchors.margins: 22
            url: root.hasFace ? "file://" + Quickshell.env("HOME") + "/.face" : ""
            step: 3
        }
    }
}
