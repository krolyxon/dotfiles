import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Services.Notifications

// A notification (panel history, toasts): the app icon in a circle (dots / mono / colour, Settings.appIcons),
// APP · 3 MIN, summary, body, other actions as pills. Click = the default action, if the app sent one.
// Critical = accent border. Ported from glyph-rice (github.com/Nebelung-cloud/glyph-rice, GPL-3.0), quick/Quick.qml.
Rectangle {
    id: card
    required property var n          // Notification
    property bool popup: false
    readonly property bool critical: n.urgency === NotificationUrgency.Critical

    Layout.fillWidth: true
    implicitHeight: Math.max(74, body.implicitHeight + 32)
    radius: 26
    color: popup ? Theme.s1 : Theme.s2
    border.width: critical || popup ? 1 : 0
    border.color: critical ? Theme.err : Theme.mute

    readonly property bool photo: !!n.image && n.image !== ""   // avatars, covers: fill the circle
    readonly property string imgSource: {
        if (photo) return n.image
        if (n.appIcon && n.appIcon !== "") return Quickshell.iconPath(n.appIcon, true)
        return ""
    }
    readonly property var defaultAction: {
        var a = n.actions
        for (var i = 0; i < a.length; i++) if (a[i].identifier === "default") return a[i]
        return null
    }
    readonly property var buttons: {
        var a = n.actions, out = []
        for (var i = 0; i < a.length; i++) if (a[i].identifier !== "default" && a[i].text !== "") out.push(a[i])
        return out
    }

    function close() {
        if (popup) Notifs.dropPopup(n)
        else n.dismiss()
    }
    // invoke() can close the notification and destroy this card: read everything first
    function run(action) {
        var nn = n, p = popup
        if (action) action.invoke()
        if (p) Notifs.dropPopup(nn)
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: card.defaultAction ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: card.run(card.defaultAction)
    }

    Rectangle {
        id: ic
        x: 16
        y: 16
        width: 42
        height: 42
        radius: 21
        color: Theme.s3
        Icon { anchors.centerIn: parent; visible: !img.visible; text: Theme.iBell; font.pixelSize: 18 }
        Image {
            id: img
            anchors.centerIn: parent
            width: card.photo && Settings.appIcons === "dots" ? 42 : 26
            height: width
            visible: status === Image.Ready
            source: card.imgSource
            sourceSize: Qt.size(width * 2, height * 2)
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            layer.enabled: Settings.appIcons !== "colour"
            layer.effect: Settings.appIcons === "mono" ? monoFx : dotFx
        }
        Component { id: dotFx; DotMask { step: card.photo ? 3 : 2; circle: card.photo } }
        Component { id: monoFx; MultiEffect { saturation: -1 } }
    }

    ColumnLayout {
        id: body
        anchors.left: ic.right
        anchors.leftMargin: 14
        anchors.right: closeBtn.left
        anchors.rightMargin: 8
        y: 16
        spacing: 2
        Lb {
            Layout.fillWidth: true
            elide: Text.ElideRight
            px: 10
            text: (card.n.appName || "app") + (Notifs.ago(card.n) !== "" ? " · " + Notifs.ago(card.n) : "")
        }
        Text {
            Layout.fillWidth: true
            text: card.n.summary
            wrapMode: Text.Wrap
            maximumLineCount: 2
            elide: Text.ElideRight
            font.family: Theme.ui
            font.pixelSize: 15
            font.weight: Font.DemiBold
            color: Theme.fg
        }
        Text {
            visible: card.n.body !== ""
            Layout.fillWidth: true
            text: card.n.body
            textFormat: Text.StyledText
            wrapMode: Text.Wrap
            maximumLineCount: card.popup ? 4 : 6
            elide: Text.ElideRight
            font.family: Theme.ui
            font.pixelSize: 14
            color: Theme.fgDim
            linkColor: Theme.fill
        }
        Flow {
            visible: card.buttons.length > 0
            Layout.fillWidth: true
            Layout.topMargin: 8
            spacing: 6
            Repeater {
                model: card.buttons
                delegate: Chip {
                    required property var modelData
                    text: modelData.text
                    filled: true
                    px: 10
                    onClicked: card.run(modelData)
                }
            }
        }
    }

    IconBtn {
        id: closeBtn
        anchors.right: parent.right
        anchors.rightMargin: 12
        y: 14
        implicitHeight: 28
        icon: Theme.iClose
        iconSize: 13
        onClicked: card.close()
    }
}
