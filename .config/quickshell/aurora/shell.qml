import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Services.Pipewire

// aurora: bar + control panel + notifications, themed from pywal16.
ShellRoot {
    id: root

    property bool opened: false
    property int tab: 0
    property double closedAt: 0
    property string lastTab: ""
    property string lastScreen: ""
    property var panelScreen: focusedScreen()
    readonly property var focusedScr: focusedScreen()
    // centered overlay windows (wallpaper picker, clipboard, ...): one at a time, on the focused monitor
    property string overlay: ""
    property var overlayScreen: focusedScreen()
    readonly property var tabNames: ["home", "audio", "net", "bt", "sys", "notif"]

    // screen of the monitor that currently has focus (falls back to the first screen)
    function focusedScreen() {
        var m = Hyprland.focusedMonitor
        var l = Quickshell.screens
        if (m) for (var i = 0; i < l.length; i++) if (l[i].name === m.name) return l[i]
        return l.length ? l[0] : null
    }
    function close() {
        if (!opened) return
        opened = false
        closedAt = Date.now()
        lastTab = tabNames[tab]
        lastScreen = panelScreen ? panelScreen.name : ""
    }
    function toggleOverlay(name) {
        if (overlay === name) { overlay = ""; return }
        close()
        overlayScreen = focusedScreen()
        overlay = name
    }
    function openTab(name) {
        var i = tabNames.indexOf(name)
        if (i >= 0) tab = i
        panelScreen = focusedScreen()
        opened = true
    }
    // bar buttons: click once to open that tab, again to close.
    // (the focus grab already closed the panel on the press, so guard against instant re-open)
    // scr = the screen whose bar was clicked, so the panel opens on that monitor
    function togglePanel(name, scr) {
        var i = tabNames.indexOf(name)
        var sn = scr ? scr.name : ""
        if (opened && tab === i && panelScreen && panelScreen.name === sn) { close(); return }
        if (!opened && lastTab === name && lastScreen === sn && Date.now() - closedAt < 250) return
        tab = i
        panelScreen = scr
        opened = true
    }

    // keep every pipewire node bound so volume / mute / properties are readable
    PwObjectTracker { objects: Pipewire.nodes.values }

    Variants {
        model: Quickshell.screens
        Bar { onTogglePanel: (name, scr) => root.togglePanel(name, scr) }
    }

    ControlPanel {
        screen: root.panelScreen
        opened: root.opened
        tab: root.tab
        onTabRequested: i => root.tab = i
        onCloseRequested: root.close()
        onOverlayRequested: name => { root.close(); root.toggleOverlay(name) }
    }

    ClipWindow {
        screen: root.overlayScreen
        opened: root.overlay === "clip"
        onCloseRequested: root.overlay = ""
    }

    WallPicker {
        screen: root.overlayScreen
        opened: root.overlay === "wall"
        onCloseRequested: root.overlay = ""
    }

    NotifPopups { screen: root.focusedScr; suppressed: root.opened }

    Osd { id: osd; screen: root.focusedScr; suppressed: root.opened }
    Connections {
        target: Bright
        // brightnessctl only knows the laptop panel; external monitors go through ddcutil (no readback)
        function onStepped() {
            var m = Hyprland.focusedMonitor
            if (Bright.available && (!m || m.name.indexOf("eDP") === 0))
                osd.show(Theme.iBright, Bright.percent / 100, false)
        }
    }

    IpcHandler {
        target: "shell"
        function toggle(): void { if (root.opened) root.close(); else root.openTab(root.tabNames[root.tab]) }
        function open(): void { root.openTab(root.tabNames[root.tab]) }
        function close(): void { root.close() }
        function show(name: string): void { root.openTab(name) }
        function dnd(): void { Notifs.dnd = !Notifs.dnd }
        function shot(mode: string): void { root.close(); Shot.take(mode) }   // region | window | output | ocr
        function shotsave(): void { Shot.save = !Shot.save }
        function clip(): void { root.toggleOverlay("clip") }
        function wall(): void { root.toggleOverlay("wall") }
        function wallrandom(): void { Wall.random() }
        function bright(dir: string): void { Bright.step(dir === "down" ? -1 : 1) }   // up | down
    }
}
