import QtQuick
import QtQuick.Layouts

ColumnLayout {
    id: page
    spacing: 8

    RowLayout {
        Layout.fillWidth: true
        spacing: 6
        Text {
            Layout.fillWidth: true
            text: Notifs.count + (Notifs.count === 1 ? " notification" : " notifications")
            color: Notifs.count > 0 ? Theme.accent : Theme.dim
            font.family: Theme.font
            font.pixelSize: Theme.fontSize
        }
        IconBtn {
            icon: Notifs.dnd ? Theme.iBellOff : Theme.iBell
            label: "dnd"
            active: Notifs.dnd
            onClicked: Notifs.dnd = !Notifs.dnd
        }
        IconBtn {
            icon: Theme.iTrash
            label: "clear"
            onClicked: Notifs.clearAll()
        }
    }

    SectionLabel { text: "history" }

    Text {
        visible: Notifs.count === 0
        Layout.alignment: Qt.AlignHCenter
        Layout.topMargin: 40
        text: Theme.iBell + "   all quiet"
        color: Theme.dim
        font.family: Theme.font
        font.pixelSize: Theme.fontSize + 1
    }

    Flickable {
        Layout.fillWidth: true
        Layout.fillHeight: true
        clip: true
        contentWidth: width
        contentHeight: list.implicitHeight
        boundsBehavior: Flickable.StopAtBounds
        id: flick

        ColumnLayout {
            id: list
            width: flick.width
            spacing: 6
            Repeater {
                model: { Notifs.count; return Notifs.history() }
                delegate: NotifCard {
                    required property var modelData
                    n: modelData
                }
            }
        }
    }
}
