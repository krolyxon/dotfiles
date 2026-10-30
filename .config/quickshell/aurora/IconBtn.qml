import QtQuick

// Round icon button (icon only) or pill (icon and/or caps label). Off = dark fill, active = white with black content.
Rectangle {
    id: b
    property string icon: ""
    property string label: ""
    property string keywords: ""    // settings search: a button is indexed only with keywords (SetIndex reads the source)
    property bool active: false
    property int iconSize: 16
    signal clicked()

    implicitHeight: 36
    implicitWidth: label === "" ? height : content.implicitWidth + 28
    radius: height / 2
    color: active ? Theme.fill : (m.containsMouse ? Theme.s3 : Theme.s2)
    Behavior on color { enabled: Theme.motion; ColorAnimation { duration: Theme.t } }

    Row {
        id: content
        anchors.centerIn: parent
        spacing: 8
        Icon {
            visible: b.icon !== ""
            anchors.verticalCenter: parent.verticalCenter
            text: b.icon
            font.pixelSize: b.iconSize
            color: b.active ? Theme.fillFg : Theme.fg
        }
        Lb {
            visible: b.label !== ""
            anchors.verticalCenter: parent.verticalCenter
            text: b.label
            px: 11
            color: b.active ? Theme.fillFg : Theme.fg
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
