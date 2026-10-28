import QtQuick

// Level slider (control panel): a pill whose filled part is white with the icon in it, the rest a row of dots,
// the value in a chip on the right. Click/drag sets (the wheel scrolls past it), the icon end toggles mute (iconClicked).
// Ported from glyph-rice (github.com/Nebelung-cloud/glyph-rice, GPL-3.0), quick/Quick.qml (Slider).
Item {
    id: r
    property string icon: ""
    property real value: 0
    property bool muted: false
    property string valueText: Math.round(shown * 100) + "%"
    signal moved(real v)
    signal iconClicked()

    readonly property real shown: area.pressed ? area.v : value

    implicitWidth: 300
    implicitHeight: 52

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: Theme.s2
    }
    // the empty part: a dot every 11px (the fill covers the rest)
    Row {
        x: 10
        anchors.verticalCenter: parent.verticalCenter
        spacing: 11 - 2.8
        Repeater {
            model: Math.max(0, Math.floor((r.width - 20) / 11) + 1)
            Rectangle { width: 2.8; height: 2.8; radius: 1.4; color: Theme.mute }
        }
    }
    Rectangle {
        width: Math.max(height, r.width * Math.max(0, Math.min(1, r.shown)))
        height: parent.height
        radius: height / 2
        color: r.muted ? Theme.grey : Theme.fill
        Icon {
            x: 17
            anchors.verticalCenter: parent.verticalCenter
            text: r.icon
            font.pixelSize: 20
            color: Theme.fillFg
        }
    }
    Rectangle {
        anchors.right: parent.right
        anchors.rightMargin: 10
        anchors.verticalCenter: parent.verticalCenter
        width: val.implicitWidth + 16
        height: val.implicitHeight + 8
        radius: 10
        color: Theme.s2
        Lb { id: val; anchors.centerIn: parent; text: r.valueText }
    }

    MouseArea {
        id: area
        property real v: 0
        anchors.fill: parent
        preventStealing: true
        cursorShape: Qt.PointingHandCursor
        function set(x) { v = Math.max(0, Math.min(1, x / width)); r.moved(v) }
        onPressed: e => set(e.x)
        onPositionChanged: e => { if (pressed) set(e.x) }
        // no onWheel on purpose: the wheel scrolls the page (it kept changing volume/brightness by accident)
    }
    // the icon end: mute
    MouseArea {
        width: r.height
        height: r.height
        cursorShape: Qt.PointingHandCursor
        onClicked: r.iconClicked()
    }
}
