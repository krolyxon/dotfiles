import QtQuick

// Wide pill toggle (Wi-Fi, Bluetooth). On = white with black text, icon in a circle, name over a caps sub line.
// Click = toggle (`clicked`); the chevron or a right click = details (`menu`).
// Ported from glyph-rice (github.com/Nebelung-cloud/glyph-rice, GPL-3.0), quick/Quick.qml (Pill).
Rectangle {
    id: pill

    property bool on: false
    property string icon
    property string name
    property string sub
    property bool alert: false           // sub line needs attention (captive portal): accent dot in front of it
    signal clicked()
    signal menu()

    implicitHeight: 76
    radius: height / 2
    color: on ? Theme.fill : body.containsMouse ? Theme.s3 : Theme.s2
    Behavior on color { enabled: Theme.motion; ColorAnimation { duration: Theme.t } }

    MouseArea {
        id: body
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: mouse => { if (mouse.button === Qt.RightButton) pill.menu(); else pill.clicked() }
    }

    Rectangle {
        id: ic
        x: 12
        anchors.verticalCenter: parent.verticalCenter
        width: 52
        height: 52
        radius: 26
        color: pill.on ? Theme.fillFg : Theme.s3
        Icon { anchors.centerIn: parent; text: pill.icon; font.pixelSize: 22; color: pill.on ? Theme.fill : Theme.fg }
    }
    Column {
        anchors.left: ic.right
        anchors.leftMargin: 12
        anchors.right: chev.left
        anchors.verticalCenter: parent.verticalCenter
        Text {
            width: parent.width
            elide: Text.ElideRight
            text: pill.name
            font.family: Theme.ui
            font.pixelSize: 16
            font.weight: Font.DemiBold
            color: pill.on ? Theme.fillFg : Theme.fg
        }
        Row {
            width: parent.width
            spacing: 6
            Rectangle {
                visible: pill.alert
                anchors.verticalCenter: parent.verticalCenter
                width: 6
                height: 6
                radius: 3
                color: Theme.live
            }
            Text {
                width: parent.width - (pill.alert ? 12 : 0)
                elide: Text.ElideRight
                text: pill.sub
                font.family: Theme.mono
                font.pixelSize: 11
                font.letterSpacing: 0.9
                font.capitalization: Font.AllUppercase
                color: pill.on ? Theme.fillFg : Theme.fg
                opacity: 0.6
            }
        }
    }
    // the chevron has its own hit area on top: details without toggling the radio
    Item {
        id: chev
        anchors.right: parent.right
        width: 46
        height: parent.height
        Icon {
            anchors.centerIn: parent
            anchors.horizontalCenterOffset: -6
            text: Theme.iChevron
            font.pixelSize: 18
            color: pill.on ? Theme.fillFg : Theme.fg
            opacity: cm.containsMouse ? 1 : 0.4
        }
        MouseArea {
            id: cm
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: pill.menu()
        }
    }
}
