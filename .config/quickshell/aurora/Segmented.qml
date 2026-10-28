import QtQuick

// One-of-n choice: a pill track where the white cell slides to the selected option.
// options: [{value, label, ticks}] (ticks = optional strength marks, how many of 4 are lit, like glyph's power modes).
// Ported from glyph-rice (github.com/Nebelung-cloud/glyph-rice, GPL-3.0), quick/Quick.qml (power modes).
Rectangle {
    id: root

    property var options: []
    property var value
    signal picked(var v)

    readonly property int at: {
        for (var i = 0; i < options.length; i++) if (options[i].value === value) return i
        return -1
    }
    readonly property real cell: (width - 12) / Math.max(1, options.length)

    implicitHeight: 54
    radius: height / 2
    color: Theme.s2

    Rectangle {
        visible: root.at >= 0
        x: 6 + root.cell * Math.max(0, root.at)
        y: 6
        width: root.cell
        height: root.height - 12
        radius: height / 2
        color: Theme.fill
        Behavior on x {
            enabled: Theme.motion
            NumberAnimation { duration: Theme.t; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.glide }
        }
    }
    Repeater {
        model: root.options
        Item {
            id: c
            required property var modelData
            required property int index
            readonly property bool on: root.at === index
            x: 6 + root.cell * index
            width: root.cell
            height: root.height
            Row {
                anchors.centerIn: parent
                spacing: 9
                Row {
                    visible: c.modelData.ticks !== undefined
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 3
                    Repeater {
                        model: 4
                        Rectangle {
                            required property int index
                            anchors.bottom: parent.bottom
                            width: 4
                            height: 6 + index * 4
                            radius: 2
                            color: index < (c.modelData.ticks || 0) ? (c.on ? Theme.fillFg : Theme.fg) : (c.on ? Theme.fade(Theme.fillFg, 0.3) : Theme.s3)
                        }
                    }
                }
                Lb {
                    anchors.verticalCenter: parent.verticalCenter
                    text: c.modelData.label
                    px: 11
                    color: c.on ? Theme.fillFg : hov.hovered ? Theme.fg : Theme.grey
                }
            }
            HoverHandler { id: hov; cursorShape: Qt.PointingHandCursor }
            TapHandler { onTapped: root.picked(c.modelData.value) }
        }
    }
}
