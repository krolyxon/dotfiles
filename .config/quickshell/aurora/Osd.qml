import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Pipewire

// Volume / mic / brightness popup: bottom-centre, click-through, auto-hides.
// Volume + mute changes are picked up natively from Pipewire (any source: keys, wpctl, panel).
// Brightness is pushed in via show() from the `bright` IPC call.
PanelWindow {
    id: win
    property bool suppressed: false      // hidden while the control panel is open
    property bool shown: false
    property string icon: ""
    property real value: 0
    property bool muted: false
    property string valueText: ""

    function show(icon, value, muted, valueText) {
        win.icon = icon
        win.value = value
        win.muted = muted
        win.valueText = valueText !== undefined ? valueText : Math.round(value * 100) + "%"
        shown = true
        hide.restart()
    }

    visible: shown && !suppressed
    anchors.bottom: true
    margins.bottom: 80
    implicitWidth: 280
    implicitHeight: 40
    exclusiveZone: 0
    color: "transparent"
    mask: Region {}
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "aurora-osd"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    Timer { id: hide; interval: 1500; onTriggered: win.shown = false }

    // ---- pipewire watchers ----
    // ignore the burst of change signals on startup and when the default device switches
    property bool armed: false
    Timer { id: arm; interval: 1000; running: true; onTriggered: win.armed = true }
    function rearm() { armed = false; arm.restart() }

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var source: Pipewire.defaultAudioSource
    onSinkChanged: rearm()
    onSourceChanged: rearm()

    function showVol() {
        var a = sink ? sink.audio : null
        if (!armed || !a) return
        show(Theme.volIcon(a.volume, a.muted), a.volume, a.muted)
    }
    Connections {
        target: win.sink ? win.sink.audio : null
        function onVolumeChanged() { win.showVol() }
        function onMutedChanged() { win.showVol() }
    }
    Connections {
        target: win.source ? win.source.audio : null
        function onMutedChanged() {
            var a = win.source.audio
            if (!win.armed) return
            win.show(a.muted ? Theme.iMicOff : Theme.iMic, a.volume, a.muted, a.muted ? "muted" : "on")
        }
    }

    // ---- ui ----
    Rectangle {
        anchors.fill: parent
        color: Theme.bgA
        border.width: 1
        border.color: Theme.accent

        Row {
            anchors.fill: parent
            anchors.leftMargin: 12
            anchors.rightMargin: 12
            spacing: 10

            Text {
                anchors.verticalCenter: parent.verticalCenter
                width: 20
                text: win.icon
                color: win.muted ? Theme.dim : Theme.fg
                font.family: Theme.font
                font.pixelSize: 16
            }
            BarSlider {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - 20 - 44 - parent.spacing * 2
                value: win.value
                muted: win.muted
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                width: 44
                horizontalAlignment: Text.AlignRight
                text: win.valueText
                color: win.muted ? Theme.dim : Theme.fg
                font.family: Theme.font
                font.pixelSize: Theme.fontSize
                font.bold: true
            }
        }
    }
}
