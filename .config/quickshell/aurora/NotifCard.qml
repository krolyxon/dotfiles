import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Notifications

Rectangle {
    id: card
    required property var n          // Notification
    property bool popup: false

    Layout.fillWidth: true
    implicitHeight: body.implicitHeight + 20
    color: popup ? Theme.bg : Theme.surface
    border.width: popup ? 2 : 1
    border.color: n.urgency === NotificationUrgency.Critical ? Theme.err : (popup ? Theme.accent : Theme.line)

    readonly property string imgSource: {
        if (n.image && n.image !== "") return n.image
        if (n.appIcon && n.appIcon !== "") return Quickshell.iconPath(n.appIcon, true)
        return ""
    }

    function close() {
        if (popup) Notifs.dropPopup(n)
        else n.dismiss()
    }

    MouseArea {
        anchors.fill: parent
        onClicked: if (card.popup) Notifs.dropPopup(card.n)
    }

    RowLayout {
        id: body
        anchors.fill: parent
        anchors.margins: 10
        spacing: 10

        Image {
            visible: card.imgSource !== ""
            source: card.imgSource
            Layout.preferredWidth: 36
            Layout.preferredHeight: 36
            Layout.alignment: Qt.AlignTop
            sourceSize: Qt.size(72, 72)
            fillMode: Image.PreserveAspectFit
            asynchronous: true
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2

            RowLayout {
                Layout.fillWidth: true
                Text {
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                    text: card.n.appName
                    color: Theme.accent
                    font.family: Theme.font
                    font.pixelSize: Theme.fontSize - 3
                    font.letterSpacing: 1
                }
                IconBtn {
                    icon: Theme.iClose
                    iconSize: 12
                    implicitWidth: 22
                    implicitHeight: 22
                    onClicked: card.close()
                }
            }
            Text {
                Layout.fillWidth: true
                text: card.n.summary
                wrapMode: Text.Wrap
                maximumLineCount: 2
                elide: Text.ElideRight
                color: Theme.fg
                font.family: Theme.font
                font.pixelSize: Theme.fontSize
                font.bold: true
            }
            Text {
                visible: card.n.body !== ""
                Layout.fillWidth: true
                text: card.n.body
                textFormat: Text.StyledText
                wrapMode: Text.Wrap
                maximumLineCount: card.popup ? 4 : 6
                elide: Text.ElideRight
                color: Theme.dim
                font.family: Theme.font
                font.pixelSize: Theme.fontSize - 1
            }
            Flow {
                visible: card.n.actions.length > 0
                Layout.fillWidth: true
                spacing: 6
                Repeater {
                    model: card.n.actions
                    delegate: IconBtn {
                        required property var modelData
                        label: modelData.text
                        implicitHeight: 24
                        // invoke() can close the notification and destroy this card: read everything first
                        onClicked: {
                            var action = modelData, n = card.n, popup = card.popup
                            action.invoke()
                            if (popup) Notifs.dropPopup(n)
                        }
                    }
                }
            }
        }
    }
}
