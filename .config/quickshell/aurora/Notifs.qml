pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Notifications

// Native notification daemon: toasts + history + do-not-disturb.
// Stop dunst/mako first, only one daemon can own org.freedesktop.Notifications.
Singleton {
    id: root
    property bool dnd: false

    // sound played on every toast (silenced by do-not-disturb, except critical ones)
    property bool soundEnabled: Settings.notifSound
    property string soundFile: Quickshell.env("HOME") + "/.config/quickshell/aurora/sounds/Blow.aiff"
    property real soundVolume: Settings.notifVolume
    property var popups: []              // [{n, until}]
    property var times: ({})             // notification id -> arrival (ms), for "3 MIN" labels
    property double now: Date.now()      // ticks while there are notifications, so the labels age
    readonly property var model: server.trackedNotifications
    readonly property int count: server.trackedNotifications.values.length

    function history() {                 // newest first
        var l = server.trackedNotifications.values, out = []
        for (var i = l.length - 1; i >= 0; i--) out.push(l[i])
        return out
    }
    function clearAll() {
        var l = server.trackedNotifications.values, all = []
        for (var i = 0; i < l.length; i++) all.push(l[i])
        for (var j = 0; j < all.length; j++) all[j].dismiss()
        popups = []
    }
    // "now" / "3 min" / "2 h" since it arrived; "" if it came before a restart
    function ago(n) {
        var t = times[n.id]
        if (!t) return ""
        var m = Math.floor((now - t) / 60000)
        return m < 1 ? "now" : m < 60 ? m + " min" : Math.floor(m / 60) + " h"
    }
    function dropPopup(n) {
        popups = popups.filter(function (p) { return p.n !== n })
    }
    function playSound() {
        if (!soundEnabled) return
        Quickshell.execDetached(["sh", "-c",
            '[ -f "$1" ] || exit 0; pw-play --volume="$2" "$1" 2>/dev/null || paplay "$1" 2>/dev/null',
            "sh", soundFile, String(soundVolume)])
    }
    function push(n) {
        playSound()
        // expireTimeout is already in ms; apps asking for less than 15s get less, never more
        var ms = (n.urgency !== NotificationUrgency.Critical && n.expireTimeout > 0)
               ? Math.min(n.expireTimeout, 15000) : 15000
        var next = popups.concat([{ n: n, until: Date.now() + ms }])
        popups = next.slice(-4)
        n.closed.connect(function () { root.dropPopup(n) })
    }

    NotificationServer {
        id: server
        keepOnReload: true
        actionsSupported: true
        bodyMarkupSupported: true
        imageSupported: true
        onNotification: n => {
            n.tracked = true
            root.times[n.id] = Date.now()
            root.now = Date.now()
            if (!root.dnd || n.urgency === NotificationUrgency.Critical) root.push(n)
        }
    }

    Timer {
        interval: 30000
        running: root.count > 0
        repeat: true
        onTriggered: root.now = Date.now()
    }

    Timer {
        interval: 500
        running: root.popups.length > 0
        repeat: true
        onTriggered: {
            var now = Date.now()
            var keep = root.popups.filter(function (p) { return p.until > now })
            if (keep.length !== root.popups.length) root.popups = keep
        }
    }
}
