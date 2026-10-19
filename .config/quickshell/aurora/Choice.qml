import QtQuick
import QtQuick.Layouts

// label + segmented buttons. options: [{value, label}] (settings app)
RowLayout {
    id: c
    property string label: ""
    property var options: []
    property var value
    signal picked(var v)
    Layout.fillWidth: true
    spacing: 8
    Text {
        Layout.preferredWidth: 150
        text: c.label
        color: Theme.fg
        elide: Text.ElideRight
        font.family: Theme.font
        font.pixelSize: Theme.fontSize
    }
    RowLayout {
        Layout.fillWidth: true
        spacing: 2
        Repeater {
            model: c.options
            delegate: IconBtn {
                required property var modelData
                Layout.fillWidth: true
                Layout.preferredWidth: 1      // equal widths, whatever the label length
                implicitHeight: 26
                label: modelData.label
                active: c.value === modelData.value
                onClicked: c.picked(modelData.value)
            }
        }
    }
}
