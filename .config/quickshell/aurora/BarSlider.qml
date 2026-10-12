import QtQuick

Item {
    id: s
    property real value: 0
    property real from: 0
    property real to: 1
    property real step: 0.02
    property bool muted: false
    signal moved(real v)

    readonly property real frac: to > from ? Math.max(0, Math.min(1, (value - from) / (to - from))) : 0

    implicitHeight: 20

    Rectangle {
        id: track
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width
        height: 6
        color: Theme.surfaceHi

        Rectangle {
            width: parent.width * s.frac
            height: parent.height
            opacity: s.muted ? 0.35 : 1
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0; color: Theme.accentDim }
                GradientStop { position: 1; color: Theme.accent }
            }
        }
    }

    Rectangle {
        x: Math.max(0, Math.min(s.width - width, s.width * s.frac - width / 2))
        anchors.verticalCenter: parent.verticalCenter
        width: 4
        height: 14
        color: Theme.fg
        opacity: s.muted ? 0.5 : 1
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        function setFromX(mx) {
            var f = Math.max(0, Math.min(1, mx / width))
            s.moved(s.from + f * (s.to - s.from))
        }
        onPressed: m => setFromX(m.x)
        onPositionChanged: m => { if (pressed) setFromX(m.x) }
        onWheel: w => {
            var d = (w.angleDelta.y > 0 ? 1 : -1) * s.step * (s.to - s.from)
            s.moved(Math.max(s.from, Math.min(s.to, s.value + d)))
        }
    }
}
