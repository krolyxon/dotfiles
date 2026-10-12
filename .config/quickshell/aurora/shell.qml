import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire

// aurora: bar + control panel + notifications, themed from pywal16.
ShellRoot {
    id: root

    property bool opened: false
    property int tab: 0
    property double closedAt: 0
    property string lastTab: ""
    readonly property var tabNames: ["home", "audio", "net", "bt", "sys", "notif"]

    function close() {
        if (!opened) return
        opened = false
        closedAt = Date.now()
        lastTab = tabNames[tab]
    }
    function openTab(name) {
        var i = tabNames.indexOf(name)
        if (i >= 0) tab = i
        opened = true
    }
    // bar buttons: click once to open that tab, again to close.
    // (the focus grab already closed the panel on the press, so guard against instant re-open)
    function togglePanel(name) {
        var i = tabNames.indexOf(name)
        if (opened && tab === i) { close(); return }
        if (!opened && lastTab === name && Date.now() - closedAt < 250) return
        tab = i
        opened = true
    }

    // keep every pipewire node bound so volume / mute / properties are readable
    PwObjectTracker { objects: Pipewire.nodes.values }

    Variants {
        model: Quickshell.screens
        Bar { onTogglePanel: name => root.togglePanel(name) }
    }

    ControlPanel {
        opened: root.opened
        tab: root.tab
        onTabRequested: i => root.tab = i
        onCloseRequested: root.close()
    }

    NotifPopups { suppressed: root.opened }

    IpcHandler {
        target: "shell"
        function toggle(): void { if (root.opened) root.close(); else root.opened = true }
        function open(): void { root.opened = true }
        function close(): void { root.close() }
        function show(name: string): void { root.openTab(name) }
        function dnd(): void { Notifs.dnd = !Notifs.dnd }
    }
}
