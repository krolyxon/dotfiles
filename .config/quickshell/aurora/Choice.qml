import QtQuick
import QtQuick.Layouts

// A settings row: label + a segmented pill where the primary cell slides to the choice. options: [{value, label}]
RowLayout {
    id: c
    property string label: ""
    property string keywords: ""    // synonyms for the settings search (SetIndex reads them from the source)
    property var options: []
    property var value
    signal picked(var v)
    Layout.fillWidth: true
    Layout.leftMargin: 18
    spacing: 16
    Text {
        Layout.preferredWidth: 200
        text: c.label
        color: Theme.fg
        elide: Text.ElideRight
        font.family: Theme.ui
        font.pixelSize: 15
    }
    Segmented {
        Layout.fillWidth: true
        implicitHeight: 46
        options: c.options
        value: c.value
        onPicked: v => c.picked(v)
    }
}
