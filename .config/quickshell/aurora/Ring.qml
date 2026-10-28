import QtQuick

// A ring of n LED dots on the item's edge; the fraction f lights clockwise from 12 o'clock, in a wave (8 ms a dot).
// Dot centres sit on the edge, so leave dot/2 of room around it.
// Ported from glyph-rice (github.com/Nebelung-cloud/glyph-rice, GPL-3.0), components/Ring.qml.
Item {
    id: root

    property int n: 44
    property real f: 1
    property real dot: 6
    property color on: Theme.fill
    property color off: Theme.s3
    readonly property int lit: Math.round(n * Math.max(0, Math.min(1, f)))

    Repeater {
        model: root.n

        Rectangle {
            required property int index
            readonly property real a: index / root.n * 2 * Math.PI - Math.PI / 2
            x: root.width / 2 * (1 + Math.cos(a)) - width / 2
            y: root.height / 2 * (1 + Math.sin(a)) - height / 2
            width: root.dot
            height: root.dot
            radius: root.dot / 2
            color: index < root.lit ? root.on : root.off
            Behavior on color {
                enabled: Theme.motion
                SequentialAnimation { PauseAnimation { duration: index * 8 } ColorAnimation { duration: 120 } }
            }
        }
    }
}
