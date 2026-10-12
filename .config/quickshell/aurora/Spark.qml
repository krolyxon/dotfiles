import QtQuick

// Bar-graph history, same flavour as the visualizer bars in your screenshot.
Item {
    id: s
    property var values: []
    property int slots: 40
    implicitHeight: 44

    Row {
        anchors.fill: parent
        spacing: 2
        Repeater {
            model: s.slots
            delegate: Item {
                required property int index
                readonly property int vi: s.values.length - s.slots + index
                readonly property real v: vi >= 0 && vi < s.values.length ? s.values[vi] : 0
                width: (s.width - (s.slots - 1) * 2) / s.slots
                height: s.height
                Rectangle {
                    anchors.bottom: parent.bottom
                    width: parent.width
                    height: Math.max(2, parent.height * parent.v)
                    gradient: Gradient {
                        GradientStop { position: 0; color: Theme.accent }
                        GradientStop { position: 1; color: Theme.accentDim }
                    }
                }
            }
        }
    }
}
