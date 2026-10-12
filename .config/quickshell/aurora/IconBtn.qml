import QtQuick

Rectangle {
    id: b
    property string icon: ""
    property string label: ""
    property bool active: false
    property int iconSize: 15
    signal clicked()

    implicitWidth: Math.max(30, content.implicitWidth + 16)
    implicitHeight: 30
    color: active ? Theme.accent : (m.containsMouse ? Theme.surfaceHi : "transparent")
    border.width: 1
    border.color: (active || m.containsMouse) ? Theme.accent : Theme.line

    Row {
        id: content
        anchors.centerIn: parent
        spacing: 6
        Text {
            visible: b.icon !== ""
            text: b.icon
            color: b.active ? Theme.bg : Theme.fg
            font.family: Theme.font
            font.pixelSize: b.iconSize
            anchors.verticalCenter: parent.verticalCenter
        }
        Text {
            visible: b.label !== ""
            text: b.label
            color: b.active ? Theme.bg : Theme.fg
            font.family: Theme.font
            font.pixelSize: Theme.fontSize - 1
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    MouseArea {
        id: m
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: b.clicked()
    }
}
