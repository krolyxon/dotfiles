import QtQuick

// previous · play/pause in the accent circle (the live thing on a media card) · next.
// Ported from glyph-rice (github.com/Nebelung-cloud/glyph-rice, GPL-3.0), components/Controls.qml.
Row {
    id: root

    property var player: Media.player
    property real size: 22               // prev/next glyphs
    property real play: 52               // play circle

    spacing: size

    Icon {
        anchors.verticalCenter: parent.verticalCenter
        text: Theme.iPrev
        font.pixelSize: root.size
        color: root.player && root.player.canGoPrevious ? Theme.fg : Theme.mute
        HoverHandler { cursorShape: Qt.PointingHandCursor }
        TapHandler { onTapped: if (root.player && root.player.canGoPrevious) root.player.previous() }
    }
    Rectangle {
        width: root.play
        height: root.play
        radius: root.play / 2
        color: Theme.live
        Icon {
            anchors.centerIn: parent
            text: root.player && root.player.isPlaying ? Theme.iPause : Theme.iPlay
            color: Theme.liveFg
            font.pixelSize: root.play * 0.46
        }
        HoverHandler { cursorShape: Qt.PointingHandCursor }
        TapHandler { onTapped: Media.toggle(root.player) }
    }
    Icon {
        anchors.verticalCenter: parent.verticalCenter
        text: Theme.iNext
        font.pixelSize: root.size
        color: root.player && root.player.canGoNext ? Theme.fg : Theme.mute
        HoverHandler { cursorShape: Qt.PointingHandCursor }
        TapHandler { onTapped: if (root.player && root.player.canGoNext) root.player.next() }
    }
}
