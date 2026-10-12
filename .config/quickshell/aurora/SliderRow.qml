import QtQuick
import QtQuick.Layouts

RowLayout {
    id: r
    property string icon: ""
    property real value: 0
    property bool muted: false
    property string valueText: Math.round(value * 100) + "%"
    signal moved(real v)
    signal iconClicked()

    spacing: 8

    IconBtn { icon: r.icon; onClicked: r.iconClicked() }
    BarSlider {
        Layout.fillWidth: true
        value: r.value
        muted: r.muted
        onMoved: v => r.moved(v)
    }
    Text {
        text: r.valueText
        Layout.preferredWidth: 40
        horizontalAlignment: Text.AlignRight
        color: r.muted ? Theme.dim : Theme.fg
        font.family: Theme.font
        font.pixelSize: Theme.fontSize
    }
}
