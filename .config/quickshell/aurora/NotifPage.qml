import QtQuick
import QtQuick.Layouts

// Control panel > notifications: the count in Doto, do-not-disturb, clear, the history.
ColumnLayout {
    id: page
    spacing: 12

    RowLayout {
        Layout.fillWidth: true
        Layout.leftMargin: 6
        spacing: 12
        Num {
            text: Notifs.count
            font.pixelSize: 44
        }
        Lb {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            text: Notifs.count === 1 ? "notification" : "notifications"
        }
        IconBtn {
            icon: Notifs.dnd ? Theme.iBellOff : Theme.iBell
            label: "dnd"
            active: Notifs.dnd
            onClicked: Notifs.dnd = !Notifs.dnd
        }
        IconBtn {
            visible: Notifs.count > 0
            icon: Theme.iTrash
            label: "clear"
            onClicked: Notifs.clearAll()
        }
    }

    Lb {
        visible: Notifs.count === 0
        Layout.alignment: Qt.AlignHCenter
        Layout.topMargin: 30
        Layout.bottomMargin: 30
        text: "all quiet"
        color: Theme.mute
    }

    Flickable {
        id: flick
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.preferredHeight: list.implicitHeight
        clip: true
        contentWidth: width
        contentHeight: list.implicitHeight
        boundsBehavior: Flickable.StopAtBounds

        ColumnLayout {
            id: list
            width: flick.width
            spacing: 10
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
