pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Mpris

// The MPRIS player the UI shows: the first one playing, else the first one (control panel, home screen).
// MPRIS doesn't push position updates: whoever shows the position pokes positionChanged() on a timer while playing.
Singleton {
    id: root

    function pick() {
        var l = Mpris.players.values, first = null
        for (var i = 0; i < l.length; i++) {
            if (l[i].isPlaying) return l[i]
            if (first === null) first = l[i]
        }
        return first
    }
    readonly property var player: pick()
    readonly property bool playing: player !== null && player.isPlaying
    readonly property bool seekable: player !== null && player.lengthSupported && player.length > 0

    function fmt(s) {                    // 75 -> "1:15"
        s = Math.max(0, Math.floor(s))
        var m = Math.floor(s / 60), r = s % 60
        return m + ":" + (r < 10 ? "0" : "") + r
    }
}
