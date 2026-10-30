import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland

// The desktop layer of one monitor (Bottom layer: above the wallpaper, under windows, never takes input), in the
// Nothing style: a Doto clock (colon blinks while the workspace is empty), the date in spaced caps behind the live dot,
// a stats line, what's playing; cava along the bottom as columns of dots while music plays (Settings.desktopViz).
PanelWindow {
    id: win
    required property var modelData
    screen: modelData
    readonly property bool showClock: Settings.desktopClock
    readonly property bool showViz: Settings.desktopViz

    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    mask: Region {}
    WlrLayershell.layer: WlrLayer.Bottom
    WlrLayershell.namespace: "aurora-desktop"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    readonly property var hmon: Hyprland.monitorFor(modelData)
    readonly property bool home: hmon && hmon.activeWorkspace ? hmon.activeWorkspace.toplevels.values.length === 0 : true

    SystemClock { id: clock; precision: SystemClock.Minutes }
    readonly property var player: Media.player

    // blinking colon: two frames a second, only while it can be seen
    property bool dim: false
    Timer { running: win.home && win.showClock && Settings.blink; interval: 500; repeat: true; onTriggered: win.dim = !win.dim }

    Column {
        visible: win.showClock
        x: Theme.barLeft + 56
        y: Theme.barTop + 48
        spacing: 2

        Row {
            Num { text: Theme.hh(clock.date); font.pixelSize: 96 }
            Num { text: ":"; font.pixelSize: 96; opacity: Settings.blink && win.dim ? 0.2 : 1 }
            Num { text: Qt.formatDateTime(clock.date, "mm"); font.pixelSize: 96 }
        }
        Row {
            topPadding: 14
            spacing: 12
            Rectangle { anchors.verticalCenter: parent.verticalCenter; width: 10; height: 10; radius: 5; color: Theme.live }
            Lb {
                anchors.verticalCenter: parent.verticalCenter
                text: Qt.locale("en_US").toString(clock.date, "dddd · d MMMM")
                px: 16
                color: Theme.fg
            }
        }
        Item { width: 1; height: 14 }
        Row {
            spacing: 22
            Stat { icon: Theme.iChip; text: Math.round(SysStats.cpu * 100) + "%" }
            Stat { icon: Theme.iMem; text: SysStats.memUsed.toFixed(1) + " / " + SysStats.memTotal.toFixed(1) + "g" }
            Stat { icon: Theme.iClock; text: "up " + Theme.fmtTime(SysStats.uptime) }
        }
        Row {
            topPadding: 8
            spacing: 10
            visible: win.player !== null && (win.player.trackTitle || "") !== ""
            Icon {
                anchors.verticalCenter: parent.verticalCenter
                text: win.player && win.player.isPlaying ? Theme.iMusic : Theme.iPause
                font.pixelSize: 15
                color: win.player && win.player.isPlaying ? Theme.fill : Theme.grey
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: win.player ? win.player.trackTitle + (win.player.trackArtist ? "  ·  " + win.player.trackArtist : "") : ""
                color: win.player && win.player.isPlaying ? Theme.fg : Theme.fgDim
                font.family: Theme.ui
                font.pixelSize: 15
            }
        }
    }

    // visualizer: a column of dots per bar along the bottom, lit from the bottom up, the top dot of each column brightest
    Row {
        id: viz
        visible: win.showViz && Cava.available && win.home
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 18
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.horizontalCenterOffset: Theme.barLeft / 2   // not under a vertical bar
        readonly property int rows: 14
        readonly property real d: 6
        readonly property real gap: Math.max(2, (win.width - Theme.barLeft - 72) / Cava.bars - d)
        spacing: gap
        Repeater {
            model: Cava.bars
            delegate: Column {
                required property int index
                readonly property real v: index < Cava.values.length ? Cava.values[index] : 0
                readonly property int lit: Math.round(v * viz.rows)
                spacing: 4
                Repeater {
                    model: viz.rows
                    Rectangle {
                        required property int index
                        readonly property int up: viz.rows - index          // rows .. 1, top to bottom
                        width: viz.d
                        height: viz.d
                        radius: viz.d / 2
                        color: up === parent.lit ? Theme.fill : up < parent.lit ? Theme.fade(Theme.fill, 0.45) : Theme.fade(Theme.s3, 0.5)
                    }
                }
            }
        }
    }

    component Stat: Row {
        property string icon
        property string text
        spacing: 8
        Icon { anchors.verticalCenter: parent.verticalCenter; text: parent.icon; font.pixelSize: 15; color: Theme.grey }
        Lb { anchors.verticalCenter: parent.verticalCenter; text: parent.text; px: 12 }
    }
}
