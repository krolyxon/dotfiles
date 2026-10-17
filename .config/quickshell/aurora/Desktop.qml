import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Mpris

// Desktop layer (per monitor): clock, date, system line, now playing, cava visualizer along the bottom.
// Sits on the Bottom layer: above hyprpaper, below windows, never takes input.
PanelWindow {
    id: win
    required property var modelData
    screen: modelData
    property bool showClock: true
    property bool showViz: true

    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    mask: Region {}
    WlrLayershell.layer: WlrLayer.Bottom
    WlrLayershell.namespace: "aurora-desktop"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    SystemClock { id: clock; precision: SystemClock.Minutes }

    function pick() {
        var l = Mpris.players.values, first = null
        for (var i = 0; i < l.length; i++) {
            if (l[i].isPlaying) return l[i]
            if (first === null) first = l[i]
        }
        return first
    }
    readonly property var player: pick()

    Column {
        visible: win.showClock
        x: 56
        y: Theme.barHeight + 48
        spacing: 2

        Text {
            text: Qt.formatDateTime(clock.date, "HH:mm")
            color: Theme.fg
            font.family: Theme.font
            font.pixelSize: 96
            font.bold: true
        }
        Row {
            spacing: 10
            Rectangle { width: 4; height: 22; color: Theme.accent; anchors.verticalCenter: parent.verticalCenter }
            Text {
                text: Qt.formatDateTime(clock.date, "dddd, d MMMM").toUpperCase()
                color: Theme.accent
                font.family: Theme.font
                font.pixelSize: 18
                font.bold: true
                font.letterSpacing: 2
            }
        }
        Item { width: 1; height: 10 }
        Text {
            text: Theme.iChip + " " + Math.round(SysStats.cpu * 100) + "%   "
                  + Theme.iMem + " " + SysStats.memUsed.toFixed(1) + "/" + SysStats.memTotal.toFixed(1) + "G   "
                  + Theme.iClock + " up " + Theme.fmtTime(SysStats.uptime)
            color: Theme.dim
            font.family: Theme.font
            font.pixelSize: Theme.fontSize + 1
        }
        Text {
            visible: win.player !== null && (win.player.trackTitle || "") !== ""
            text: win.player ? (win.player.isPlaying ? Theme.iMusic : Theme.iPause) + "  " + win.player.trackTitle
                               + (win.player.trackArtist ? "  ·  " + win.player.trackArtist : "") : ""
            color: win.player && win.player.isPlaying ? Theme.fg : Theme.dim
            font.family: Theme.font
            font.pixelSize: Theme.fontSize + 1
        }
    }

    // visualizer: bottom-up bars across the whole width
    Row {
        visible: win.showViz && Cava.available
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        height: 180
        spacing: 3
        Repeater {
            model: Cava.bars
            delegate: Rectangle {
                required property int index
                readonly property real v: index < Cava.values.length ? Cava.values[index] : 0
                anchors.bottom: parent.bottom
                width: (win.width - (Cava.bars - 1) * 3) / Cava.bars
                height: Math.max(0, v * parent.height)
                opacity: 0.85
                gradient: Gradient {
                    GradientStop { position: 0; color: Theme.accent }
                    GradientStop { position: 1; color: Theme.accentDim }
                }
            }
        }
    }
}
