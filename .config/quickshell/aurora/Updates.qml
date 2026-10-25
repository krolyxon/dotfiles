pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// pending package updates: checkupdates (pacman-contrib, syncs a private db copy) + paru -Qua (AUR).
// Checked a minute after start, then every 2h; the sys tab asks for a fresh one when opened (check(false)
// skips it if the last one is under 10 min old). upgrade() runs paru in foot, started through Hyprland so
// restarting aurora can't kill a pacman transaction; the terminal calls the `updates` IPC when it closes.
Singleton {
    id: root
    property bool available: false      // checkupdates installed
    property bool checking: false
    property bool upgrading: false
    property var list: []                // [{name, from, to, aur}], repo packages first
    property int repo: 0
    property int aur: 0
    readonly property int count: repo + aur
    property date lastCheck: new Date(0)
    property string error: ""            // checkupdates failed (offline, db locked...): the old list is kept

    function check(force) {
        if (!available || checking) return
        if (!force && Date.now() - lastCheck.getTime() < 600000) return
        checking = true
        checkProc.running = true
    }

    function upgrade() {
        if (upgrading) return
        upgrading = true
        upgradeGuard.restart()
        Quickshell.execDetached(["hyprctl", "dispatch", "hl.dsp.exec_cmd([[foot -T 'system upgrade' -e sh -c "
            + "'paru; printf \"\\ndone, press enter to close\"; read _; qs -c aurora ipc call shell updates']])"])
    }
    // called by the upgrade terminal when it closes (and usable by hand after updating elsewhere)
    function finished() {
        upgrading = false
        upgradeGuard.stop()
        check(true)
    }

    // "name old -> new [ignored]" lines; @repo <exit code> separates the two lists
    function parse(text) {
        var out = [], nr = 0, na = 0, isAur = false, code = 0
        var lines = text.split("\n")
        for (var i = 0; i < lines.length; i++) {
            var l = lines[i].trim()
            var c = l.match(/^@repo (\d+)$/)
            if (c) { code = parseInt(c[1]); isAur = true; continue }
            var m = l.match(/^(\S+)\s+(\S+)\s+->\s+(\S+)/)
            if (!m || l.indexOf("[ignored]") >= 0) continue
            out.push({ name: m[1], from: m[2], to: m[3], aur: isAur })
            if (isAur) na++; else nr++
        }
        // checkupdates: 0 = updates, 2 = none, anything else = failed
        if (code !== 0 && code !== 2) {
            error = "checkupdates failed (" + code + ")"
            out = list.filter(function (p) { return !p.aur }).concat(out.filter(function (p) { return p.aur }))
            nr = repo
        } else {
            error = ""
        }
        list = out
        repo = nr
        aur = na
        lastCheck = new Date()
    }

    Process {
        command: ["sh", "-c", "command -v checkupdates"]
        running: true
        onExited: code => root.available = code === 0
    }

    Process {
        id: checkProc
        command: ["sh", "-c", 'checkupdates 2>/dev/null; echo "@repo $?"; command -v paru >/dev/null && paru -Qua 2>/dev/null; true']
        stdout: StdioCollector { onStreamFinished: { root.parse(text); root.checking = false } }
    }

    // the terminal may be closed with the window's X, skipping the IPC call
    Timer { id: upgradeGuard; interval: 3600000; onTriggered: root.upgrading = false }

    Timer { interval: 60000; running: root.available; onTriggered: root.check(true) }
    Timer { interval: 7200000; running: root.available; repeat: true; onTriggered: root.check(true) }
}
