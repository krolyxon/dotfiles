import QtQuick

// Dotted slider: a row of LED dots, the lit part white up to a larger head dot, the rest unlit.
// Click/drag sets, the wheel scrolls the page past it. muted = the lit dots go grey.
Item {
    id: s
    property real value: 0
    property real from: 0
    property real to: 1
    property real step: 0.02
    property bool muted: false
    signal moved(real v)

    readonly property real frac: to > from ? Math.max(0, Math.min(1, (value - from) / (to - from))) : 0
    readonly property int n: Math.max(2, Math.floor((width - 8) / 9) + 1)
    readonly property int head: Math.round(frac * (n - 1))

    implicitHeight: 20

    Repeater {
        model: s.n
        Rectangle {
            required property int index
            readonly property bool isHead: index === s.head
            readonly property real d: isHead ? 9 : 4
            x: 4 + index * (s.width - 8) / (s.n - 1) - d / 2
            anchors.verticalCenter: parent.verticalCenter
            width: d
            height: d
            radius: d / 2
            color: index <= s.head ? (s.muted ? Theme.grey : Theme.fill) : Theme.s3
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        preventStealing: true
        function setFromX(mx) {
            var f = Math.max(0, Math.min(1, mx / width))
            s.moved(s.from + f * (s.to - s.from))
        }
        onPressed: m => setFromX(m.x)
        onPositionChanged: m => { if (pressed) setFromX(m.x) }
        // no onWheel: a MouseArea without one passes the wheel on, so scrolling the page never moves a slider
    }
}
