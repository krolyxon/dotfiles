import QtQuick

// A waybar-style block: flat, 12px padding, 1px accent underline.
Item {
    id: p
    property string icon: ""
    property string text: ""
    property color tint: Theme.fg
    property color underline: Theme.accent
    signal activated(int button)
    signal scrolled(int dir)

    implicitWidth: row.implicitWidth + 24
    implicitHeight: parent ? parent.height : Theme.barHeight

    Rectangle {
        anchors.fill: parent
        color: m.containsMouse ? Theme.surface : "transparent"
    }
    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: 1
        color: p.underline
    }
    Row {
        id: row
        anchors.centerIn: parent
        spacing: 6
        Text {
            visible: p.icon !== ""
            text: p.icon
            color: p.tint
            font.family: Theme.font
            font.pixelSize: Theme.fontSize + 1
            anchors.verticalCenter: parent.verticalCenter
        }
        Text {
            visible: p.text !== ""
            text: p.text
            color: p.tint
            font.family: Theme.font
            font.pixelSize: Theme.fontSize
            font.bold: true
            anchors.verticalCenter: parent.verticalCenter
        }
    }
    MouseArea {
        id: m
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        onClicked: mouse => p.activated(mouse.button)
        onWheel: w => p.scrolled(w.angleDelta.y > 0 ? 1 : -1)
    }
}
