import QtQuick

// One block of the bar: icon, caps label, optional second icon with its own click (activated2), anything else declared
// inside goes after them (the battery capsule, the clock). Hover = a rounded highlight.
Item {
    id: p
    property string icon: ""
    property string text: ""
    property color tint: Theme.fg
    property color underline: "transparent"   // old style, unused
    property string icon2: ""
    property color tint2: Theme.fg
    default property alias extra: row.data
    signal activated(int button)
    signal activated2(int button)
    signal scrolled(int dir)

    implicitWidth: row.implicitWidth + 22
    implicitHeight: parent ? parent.height : Theme.barSize

    Rectangle {
        anchors.fill: parent
        anchors.topMargin: 5
        anchors.bottomMargin: 5
        radius: height / 2
        color: m.containsMouse ? Theme.s2 : "transparent"
    }
    Row {
        id: row
        anchors.centerIn: parent
        spacing: 7
        Icon {
            visible: p.icon !== ""
            anchors.verticalCenter: parent.verticalCenter
            text: p.icon
            font.pixelSize: 16
            color: p.tint
        }
        Lb {
            visible: p.text !== ""
            anchors.verticalCenter: parent.verticalCenter
            text: p.text
            px: 11
            color: p.tint
        }
        Icon {
            id: second
            visible: p.icon2 !== ""
            anchors.verticalCenter: parent.verticalCenter
            text: p.icon2
            font.pixelSize: 16
            color: p.tint2
        }
    }
    MouseArea {
        id: m
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        onClicked: mouse => {
            // split at the middle of the gap before the second icon
            if (second.visible && mouse.x >= row.x + second.x - row.spacing / 2) p.activated2(mouse.button)
            else p.activated(mouse.button)
        }
        onWheel: w => p.scrolled(w.angleDelta.y > 0 ? 1 : -1)
    }
}
