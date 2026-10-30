import QtQuick
import QtQuick.Layouts

// Section heading: grey caps label, an optional count after a middle dot, an optional action on the right (CLEAR ALL).
RowLayout {
    id: r
    property string text: ""
    property string keywords: ""    // synonyms for the settings search (SetIndex reads them from the source)
    property string count: ""
    property string action: ""
    signal actionClicked()

    Layout.fillWidth: true
    spacing: 8

    Lb {
        Layout.leftMargin: 6
        text: r.text + (r.count !== "" ? " · " + r.count : "")
    }
    Item { Layout.fillWidth: true }
    Lb {
        visible: r.action !== ""
        Layout.rightMargin: 6
        text: r.action
        color: am.containsMouse ? Theme.fg : Theme.fill
        MouseArea {
            id: am
            anchors.fill: parent
            anchors.margins: -6
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: r.actionClicked()
        }
    }
}
