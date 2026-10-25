pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Polkit

// Authentication agents, shown by AuthPrompt.
//   polkit  Quickshell's native PolkitAgent (replaced hyprpolkitagent). Polkit allows one agent per
//           session: if registering fails (another agent running), hyprpolkitagent is started as a fallback.
//   bluez   btagent.py (python-gobject), the default pairing agent: passkey confirmation, PIN/passkey
//           entry and display. JSON lines over its stdout/stdin, see the script. Restarted with backoff.
Singleton {
    id: root

    readonly property var flow: agent.flow
    readonly property bool polkitActive: agent.isActive && agent.flow !== null
    readonly property bool registered: agent.isRegistered

    PolkitAgent { id: agent }

    // ---- bluetooth: the request being shown, {id, method, alias, passkey|pincode}; id 0 = display only
    property var bt: null
    readonly property bool btActive: bt !== null
    property bool btRegistered: false
    function btReply(ok, value) {
        if (bt && bt.id) btProc.write(JSON.stringify({ id: bt.id, ok: ok, value: value || "" }) + "\n")
        bt = null
    }
    function btLine(l) {
        var m
        try { m = JSON.parse(l) } catch (e) { return }
        if (m.event === "registered") { btRegistered = true; backoff = 2000 }
        else if (m.event === "cancel") bt = null
        else if (m.event === "error") console.warn("btagent:", m.msg)
        else if (m.method) {
            if (bt && bt.id) btReply(false)      // a new request replaces an unanswered one
            bt = m
            if (!m.id) displayTimeout.restart()
        }
    }
    property int backoff: 2000
    Process {
        id: btProc
        command: ["python3", "-I", Quickshell.shellPath("btagent.py")]
        running: true
        stdinEnabled: true
        stdout: SplitParser { onRead: l => root.btLine(l) }
        stderr: SplitParser { onRead: l => console.warn("btagent:", l) }
        onExited: {
            root.bt = null
            root.btRegistered = false
            restartBt.interval = root.backoff
            root.backoff = Math.min(root.backoff * 2, 60000)
            restartBt.start()
        }
    }
    Timer { id: restartBt; onTriggered: btProc.running = true }
    // a shown passkey/PIN has no answer: drop it after a while (pairing is done or failed by then)
    Timer { id: displayTimeout; interval: 30000; onTriggered: if (root.bt && !root.bt.id) root.bt = null }

    Timer {
        interval: 5000
        running: true
        onTriggered: {
            if (agent.isRegistered) return
            Quickshell.execDetached(["notify-send", "-a", "aurora", "-i", "dialog-password", "polkit agent",
                                     "aurora couldn't register as the polkit agent, starting hyprpolkitagent instead"])
            Quickshell.execDetached(["systemctl", "--user", "start", "hyprpolkitagent"])
        }
    }
}
