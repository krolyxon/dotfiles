import QtQuick
import QtQuick.Layouts

// A settings row: label + dotted slider + value, for an integer or real setting
RowLayout {
    id: k
    property string label: ""
    property real value: 0
    property real from: 0
    property real to: 1
    property int decimals: 0
    property string unit: ""
    signal moved(real v)
    Layout.fillWidth: true
    Layout.leftMargin: 18
    Layout.rightMargin: 14
    implicitHeight: 48
    spacing: 16
    Text {
        Layout.preferredWidth: 200
        text: k.label
        color: Theme.fg
        elide: Text.ElideRight
        font.family: Theme.ui
        font.pixelSize: 15
    }
    BarSlider {
        Layout.fillWidth: true
        from: k.from
        to: k.to
        step: 1 / Math.max(1, (k.to - k.from) * (k.decimals ? 100 : 1))
        value: k.value
        onMoved: v => k.moved(k.decimals ? Math.round(v * 100) / 100 : Math.round(v))
    }
    Rectangle {
        Layout.preferredWidth: 76
        implicitHeight: 32
        radius: 16
        color: Theme.s2
        Lb {
            anchors.centerIn: parent
            text: (k.decimals ? k.value.toFixed(k.decimals) : String(Math.round(k.value))) + k.unit
            color: Theme.fg
        }
    }
}
