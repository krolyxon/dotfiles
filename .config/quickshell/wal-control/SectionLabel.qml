import QtQuick
import QtQuick.Layouts

RowLayout {
    id: r
    property string text: ""
    Layout.fillWidth: true
    spacing: 8
    Text {
        text: r.text.toUpperCase()
        color: Theme.accent
        font.family: Theme.font
        font.pixelSize: Theme.fontSize - 2
        font.letterSpacing: 1.5
    }
    Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Theme.line }
}
