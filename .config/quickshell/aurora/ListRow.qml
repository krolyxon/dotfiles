import QtQuick
import QtQuick.Layouts

// A list row: icon in a circle (white when `current`: connected, default device...), title over a caps sub line,
// a caps trailing value. Anything declared inside a ListRow {} lands in the right-hand slot (small round buttons).
Rectangle {
    id: r
    property string icon: ""
    property string title: ""
    property string subtitle: ""
    property string trailing: ""
    property bool current: false
    signal clicked()
    default property alias extra: extraRow.data

    Layout.fillWidth: true
    implicitHeight: 56
    radius: height / 2
    color: m.containsMouse ? Theme.s2 : "transparent"

    MouseArea {
        id: m
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: r.clicked()
    }

    Rectangle {
        id: ic
        x: 6
        anchors.verticalCenter: parent.verticalCenter
        width: 44
        height: 44
        radius: 22
        color: r.current ? Theme.fill : (m.containsMouse ? Theme.s3 : Theme.s2)
        Icon {
            anchors.centerIn: parent
            text: r.icon
            font.pixelSize: 19
            color: r.current ? Theme.fillFg : Theme.fg
        }
    }
    Column {
        anchors.left: ic.right
        anchors.leftMargin: 14
        anchors.right: tail.left
        anchors.rightMargin: 10
        anchors.verticalCenter: parent.verticalCenter
        spacing: 2
        Text {
            width: parent.width
            elide: Text.ElideRight
            text: r.title
            font.family: Theme.ui
            font.pixelSize: 15
            font.weight: Font.DemiBold
            color: Theme.fg
        }
        Lb {
            visible: r.subtitle !== ""
            width: parent.width
            elide: Text.ElideRight
            text: r.subtitle
            px: 10
        }
    }
    Row {
        id: tail
        anchors.right: parent.right
        anchors.rightMargin: 10
        anchors.verticalCenter: parent.verticalCenter
        spacing: 8
        Lb {
            visible: r.trailing !== ""
            anchors.verticalCenter: parent.verticalCenter
            text: r.trailing
            px: 10
        }
        Row {
            id: extraRow
            anchors.verticalCenter: parent.verticalCenter
            spacing: 6
        }
    }
}
