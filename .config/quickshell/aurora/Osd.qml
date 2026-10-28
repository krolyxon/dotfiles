import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Pipewire

// Volume / mic / brightness on the right screen edge, like the Glyph strips on the phone: 20 segments fill bottom-up
// (the lit ones glow), a capsule next to them shows the icon and the value. Click-through, fades out after
// Settings.osdTimeout. Volume + mute come natively from Pipewire (keys, wpctl, panel); brightness is pushed in with
// show() from the `bright` IPC call. After glyph-rice (github.com/Nebelung-cloud/glyph-rice, GPL-3.0), glyph/Glyph.qml.
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
        win.valueText = valueText !== undefined ? valueText : String(Math.round(value * 100))
        shown = true
        hide.restart()
    }

    property real t: shown && !suppressed ? 1 : 0
    Behavior on t { NumberAnimation { duration: Theme.t; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.glide } }

    visible: t > 0
    anchors.right: true                  // vertically centred on the right edge
    implicitWidth: 150
    implicitHeight: 520
    exclusiveZone: 0
    color: "transparent"
    mask: Region {}
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "aurora-osd"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    Timer { id: hide; interval: Settings.osdTimeout; onTriggered: win.shown = false }

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
            win.show(a.muted ? Theme.iMicOff : Theme.iMic, a.muted ? 0 : a.volume, a.muted, a.muted ? "off" : "on")
        }
    }

    // ---- ui ----
    Item {
        anchors.fill: parent
        opacity: win.t
        transform: Translate { x: 16 * (1 - win.t) }

        // the strip: unlit segments, then the lit ones on top with the glow (the glow would outline unlit ones too)
        Seg {
            id: strip
            x: parent.width - 14
            y: 10
            width: 5
            height: parent.height - 20
            n: 20
            vertical: true
            f: 0
        }
        Seg {
            x: strip.x
            y: strip.y
            width: strip.width
            height: strip.height
            n: 20
            vertical: true
            f: win.value
            on: win.muted ? Theme.grey : Theme.fill
            off: "transparent"
            layer.enabled: true
            layer.effect: MultiEffect {
                shadowEnabled: true
                shadowColor: Theme.glow
                shadowBlur: 0.7
                blurMax: 20
                shadowHorizontalOffset: 0
                shadowVerticalOffset: 0
            }
        }

        // the value next to it: icon over the number
        Rectangle {
            anchors.right: parent.right
            anchors.rightMargin: 32
            anchors.verticalCenter: parent.verticalCenter
            width: Math.max(58, box.implicitWidth + 24)
            height: box.implicitHeight + 36
            radius: width / 2
            color: Theme.s1
            border.width: 1
            border.color: Theme.s2
            Column {
                id: box
                anchors.centerIn: parent
                spacing: 12
                Icon {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: win.icon
                    font.pixelSize: 20
                    color: win.muted ? Theme.grey : Theme.fg
                }
                Num {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: win.valueText
                    font.pixelSize: 30
                    color: win.muted ? Theme.grey : Theme.fg
                }
            }
        }
    }
}
