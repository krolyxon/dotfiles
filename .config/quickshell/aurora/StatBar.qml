import QtQuick
import QtQuick.Layouts

RowLayout {
    id: r
    property string label: ""
    property real frac: 0
    property string valueText: ""
    property color fill: Theme.accent
    Layout.fillWidth: true
    spacing: 10

    Text {
        text: r.label
        Layout.preferredWidth: 72
        elide: Text.ElideRight
        color: Theme.dim
        font.family: Theme.font
        font.pixelSize: Theme.fontSize - 1
    }
    Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: 6
        color: Theme.surfaceHi
        Rectangle {
            width: parent.width * Math.max(0, Math.min(1, r.frac))
            height: parent.height
            color: r.fill
        }
    }
    Text {
        text: r.valueText
        Layout.preferredWidth: 96
        horizontalAlignment: Text.AlignRight
        color: Theme.fg
        font.family: Theme.font
        font.pixelSize: Theme.fontSize - 1
    }
}
