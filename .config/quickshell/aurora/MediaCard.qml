import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Mpris

Rectangle {
    id: card

    function pick() {
        var l = Mpris.players.values, first = null
        for (var i = 0; i < l.length; i++) {
            if (l[i].isPlaying) return l[i]
            if (first === null) first = l[i]
        }
        return first
    }
    function fmt(s) {
        s = Math.max(0, Math.floor(s))
        var m = Math.floor(s / 60), r = s % 60
        return m + ":" + (r < 10 ? "0" : "") + r
    }

    readonly property var player: pick()
    readonly property bool has: player !== null
    readonly property bool seekable: has && player.lengthSupported && player.length > 0

    implicitHeight: has ? (seekable ? 156 : 122) : 56
    color: Theme.surface
    border.width: 1
    border.color: Theme.line

    // MPRIS doesn't push position updates, so poke it while playing
    Timer {
        running: card.has && card.player.isPlaying && card.visible
        interval: 500
        repeat: true
        onTriggered: card.player.positionChanged()
    }

    Text {
        visible: !card.has
        anchors.centerIn: parent
        text: Theme.iMusic + "   nothing playing"
        color: Theme.dim
        font.family: Theme.font
        font.pixelSize: Theme.fontSize
    }

    ColumnLayout {
        visible: card.has
        anchors.fill: parent
        anchors.margins: 10
        spacing: 6

        RowLayout {
            spacing: 10
            Rectangle {
                Layout.preferredWidth: 60
                Layout.preferredHeight: 60
                color: Theme.surfaceHi
                Text {
                    anchors.centerIn: parent
                    text: Theme.iMusic
                    color: Theme.dim
                    font.family: Theme.font
                    font.pixelSize: 24
                }
                Image {
                    id: art
                    anchors.fill: parent
                    source: card.has ? card.player.trackArtUrl : ""
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    visible: status === Image.Ready
                }
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                Text {
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                    text: card.has ? (card.player.trackTitle || "unknown title") : ""
                    color: Theme.fg
                    font.family: Theme.font
                    font.pixelSize: Theme.fontSize + 1
                    font.bold: true
                }
                Text {
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                    text: card.has ? (card.player.trackArtist || "unknown artist") : ""
                    color: Theme.accent
                    font.family: Theme.font
                    font.pixelSize: Theme.fontSize
                }
                Text {
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                    text: card.has ? ((card.player.trackAlbum ? card.player.trackAlbum + "  ·  " : "") + card.player.identity) : ""
                    color: Theme.dim
                    font.family: Theme.font
                    font.pixelSize: Theme.fontSize - 2
                }
            }
        }

        RowLayout {
            visible: card.seekable
            spacing: 8
            Text {
                text: card.seekable ? card.fmt(card.player.position) : ""
                color: Theme.dim
                font.family: Theme.font
                font.pixelSize: Theme.fontSize - 2
            }
            BarSlider {
                Layout.fillWidth: true
                from: 0
                to: card.seekable ? card.player.length : 1
                value: card.seekable ? card.player.position : 0
                onMoved: v => { if (card.player.canSeek) card.player.position = v }
            }
            Text {
                text: card.seekable ? card.fmt(card.player.length) : ""
                color: Theme.dim
                font.family: Theme.font
                font.pixelSize: Theme.fontSize - 2
            }
        }

        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: 8
            IconBtn {
                icon: Theme.iPrev
                opacity: card.has && card.player.canGoPrevious ? 1 : 0.4
                onClicked: if (card.player.canGoPrevious) card.player.previous()
            }
            IconBtn {
                icon: card.has && card.player.isPlaying ? Theme.iPause : Theme.iPlay
                active: true
                implicitWidth: 44
                onClicked: if (card.player.canTogglePlaying) card.player.togglePlaying()
            }
            IconBtn {
                icon: Theme.iNext
                opacity: card.has && card.player.canGoNext ? 1 : 0.4
                onClicked: if (card.player.canGoNext) card.player.next()
            }
        }
    }
}
