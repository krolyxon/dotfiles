import QtQuick

// Mini player (control panel): the cover as dots in a circle, title / artist, a dotted seek bar, prev · play · next.
// Hidden while no MPRIS player exists. Ported from glyph-rice (github.com/Nebelung-cloud/glyph-rice, GPL-3.0), quick/Quick.qml.
Rectangle {
    id: card
    readonly property var player: Media.player
    readonly property bool has: player !== null
    readonly property bool seekable: has && player.lengthSupported && player.length > 0

    visible: has
    implicitHeight: 92
    radius: 30
    color: Theme.s2

    // MPRIS doesn't push position updates, so poke it while playing
    Timer {
        running: card.has && card.player.isPlaying && card.visible && card.seekable
        interval: 500
        repeat: true
        onTriggered: card.player.positionChanged()
    }

    DotArt {
        id: art
        x: 14
        anchors.verticalCenter: parent.verticalCenter
        width: 64
        height: 64
        step: 4
        url: card.has ? card.player.trackArtUrl : ""
    }
    Column {
        anchors.left: art.right
        anchors.leftMargin: 14
        anchors.right: ctl.left
        anchors.rightMargin: 14
        anchors.verticalCenter: parent.verticalCenter
        spacing: 2
        Text {
            width: parent.width
            elide: Text.ElideRight
            text: card.has ? (card.player.trackTitle || "Nothing on") : ""
            font.family: Theme.ui
            font.pixelSize: 15
            font.weight: Font.DemiBold
            color: Theme.fg
        }
        Item {
            width: parent.width
            height: artist.implicitHeight
            Text {
                id: artist
                anchors.left: parent.left
                anchors.right: time.left
                anchors.rightMargin: 8
                elide: Text.ElideRight
                text: card.has ? (card.player.trackArtist || card.player.identity) : ""
                font.family: Theme.ui
                font.pixelSize: 13
                color: Theme.fgDim
            }
            Lb {
                id: time
                visible: card.seekable
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                px: 9
                text: card.seekable ? Media.fmt(card.player.position) + " / " + Media.fmt(card.player.length) : ""
            }
        }
        BarSlider {
            visible: card.seekable
            width: parent.width
            implicitHeight: 16
            from: 0
            to: card.seekable ? card.player.length : 1
            value: card.seekable ? card.player.position : 0
            onMoved: v => { if (card.player.canSeek) card.player.position = v }
        }
    }
    PlayControls {
        id: ctl
        anchors.right: parent.right
        anchors.rightMargin: 16
        anchors.verticalCenter: parent.verticalCenter
        player: card.player
        size: 18
        play: 44
    }
}
