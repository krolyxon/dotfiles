import QtQuick

// Round toggle with a caption under it (control panel). Off = dark circle, on = white circle with a black icon,
// live = the accent circle (recording). Right click = menu (`picked` = its options are open: caption turns white).
// Ported from glyph-rice (github.com/Nebelung-cloud/glyph-rice, GPL-3.0), quick/Quick.qml (Tile).
Column {
    id: tile

    property string icon
    property string name
    property bool on: false
    property bool live: false
    property bool picked: false
    property real size: 68
    signal clicked()
    signal menu()

    spacing: 8

    Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        width: tile.size
        height: tile.size
        radius: tile.size / 2
        color: tile.live ? Theme.live : tile.on ? Theme.fill : m.containsMouse ? Theme.s3 : Theme.s2
        Behavior on color { enabled: Theme.motion; ColorAnimation { duration: Theme.t } }
        Icon {
            anchors.centerIn: parent
            text: tile.icon
            font.pixelSize: Math.round(tile.size * 0.35)
            color: tile.live ? Theme.liveFg : tile.on ? Theme.fillFg : Theme.fg
        }
        MouseArea {
            id: m
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onClicked: mouse => { if (mouse.button === Qt.RightButton) tile.menu(); else tile.clicked() }
        }
    }
    Lb {
        anchors.horizontalCenter: parent.horizontalCenter
        width: Math.min(implicitWidth, Math.max(tile.width, tile.size + 16))
        horizontalAlignment: Text.AlignHCenter
        elide: Text.ElideRight
        text: tile.name
        px: 10
        color: tile.picked || tile.on || tile.live ? Theme.fg : Theme.grey
    }
}
