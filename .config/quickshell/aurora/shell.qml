//@ pragma IconTheme Yaru
// ^ same as gtk-3.0: notify-send -i names (drive-removable-media, network-wireless, ...) resolve through it
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Services.Pipewire

// aurora: bar + control panel + notifications, themed from matugen.
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
    property bool barShown: true   // `bar` IPC (SUPER+B); not persisted, a restart shows it again
    property var overlayScreen: focusedScreen()
    // touch singletons that must start with the shell (Idle creates ~/.config/aurora/hypridle.conf)
    readonly property string idleFile: Idle.file
    readonly property bool batCare: Battery.ready   // charge limit + low battery warnings
    readonly property bool devWatch: Devices.scanned   // removable drive notifications
    readonly property var tabNames: ["home", "audio", "net", "bt", "sys", "notif"]
    // settings app (a normal window): open state + shown section
    property bool settingsOpen: false
    property string settingsSection: "network"

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
    property double overlayClosedAt: 0
    property string lastOverlay: ""
    function closeOverlay() {
        if (overlay === "") return
        lastOverlay = overlay
        overlayClosedAt = Date.now()
        overlay = ""
    }
    // scr: where to open (defaults to the focused monitor). Same instant re-open guard as togglePanel.
    function toggleOverlay(name, scr) {
        if (overlay === name) { closeOverlay(); return }
        if (lastOverlay === name && Date.now() - overlayClosedAt < 250) return
        close()
        overlayScreen = scr ? scr : focusedScreen()
        overlay = name
    }
    // section "" = toggle the window on its last section; a name opens (or switches) to it
    function settings(section) {
        if (section === "" || section === undefined) { settingsOpen = !settingsOpen; return }
        settingsSection = section
        settingsOpen = true
    }
    function openTab(name) {
        if (name === "settings") { settings("appearance"); return }   // old panel tab lives in the app now
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
        Desktop {}
    }

    Variants {
        model: Quickshell.screens
        Dock {}
    }

    Variants {
        model: Quickshell.screens
        Bar {
            visible: root.barShown
            onTogglePanel: (name, scr) => root.togglePanel(name, scr)
            onToggleOverlay: (name, scr) => root.toggleOverlay(name, scr)
        }
    }

    ControlPanel {
        screen: root.panelScreen
        opened: root.opened
        tab: root.tab
        onTabRequested: i => root.tab = i
        onCloseRequested: root.close()
        onOverlayRequested: name => { root.close(); root.toggleOverlay(name) }
        onSettingsRequested: { root.close(); root.settingsOpen = true }
    }

    Overview {
        screen: root.overlayScreen
        opened: root.overlay === "overview"
        onCloseRequested: root.closeOverlay()
    }

    CalPopup {
        screen: root.overlayScreen
        opened: root.overlay === "cal"
        onCloseRequested: root.closeOverlay()
    }

    ClipWindow {
        screen: root.overlayScreen
        opened: root.overlay === "clip"
        onCloseRequested: root.closeOverlay()
    }

    CharPicker {
        screen: root.overlayScreen
        opened: root.overlay === "chars"
        onCloseRequested: root.closeOverlay()
    }

    WallPicker {
        screen: root.overlayScreen
        opened: root.overlay === "wall"
        onCloseRequested: root.closeOverlay()
    }

    // polkit password prompt (Agents), on the focused monitor
    AuthPrompt { screen: root.focusedScr }

    PowerMenu {
        screen: root.overlayScreen
        opened: root.overlay === "power"
        onCloseRequested: root.closeOverlay()
    }

    Runner {
        id: runner
        screen: root.overlayScreen
        opened: root.overlay === "runner"
        shell: root
        onCloseRequested: root.closeOverlay()
        onOpenRequested: {
            root.close()
            if (root.overlay === "runner") return   // already open (run mode): it just switched to the list
            root.overlayScreen = root.focusedScreen()
            root.overlay = "runner"
        }
    }

    SettingsApp {
        opened: root.settingsOpen
        section: root.settingsSection
        onCloseRequested: root.settingsOpen = false
        onSectionRequested: name => root.settingsSection = name
        onOverlayRequested: name => root.toggleOverlay(name)
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
        // `qs ipc call shell show x` is swallowed by the qs CLI (it has its own `show`), so use this
        function tab(name: string): void { root.openTab(name) }
        function dnd(): void { Notifs.dnd = !Notifs.dnd }
        function shot(mode: string): void { root.close(); Shot.take(mode) }   // region | window | output | ocr
        function shotsave(): void { Shot.save = !Shot.save }
        function overview(): void { root.toggleOverlay("overview") }
        function cal(): void { root.toggleOverlay("cal") }
        function clip(): void { root.toggleOverlay("clip") }
        function chars(): void { root.toggleOverlay("chars") }   // glyph picker (SUPER+grave)
        function wall(): void { root.toggleOverlay("wall") }
        function power(): void { root.toggleOverlay("power") }
        function run(): void { root.toggleOverlay("runner") }
        function dmenu(dir: string): void { runner.startDmenu(dir) }   // used by ~/.local/bin/aurora-run -d
        function bar(): void { root.barShown = !root.barShown }
        function wallrandom(): void { Wall.random() }
        function wallset(path: string): void { Wall.apply(path) }   // absolute path (setwall resolves it)
        function rec(mode: string): void { root.close(); Rec.toggle(mode === "region" ? "region" : "screen") }   // screen (default) | region
        function settings(section: string): void { root.settings(section) }   // "" = toggle
        function caffeine(): void { Toggles.caffeine = !Toggles.caffeine }
        function portal(): void { Net.signIn() }   // open the captive portal login page (or say we're online)
        function bright(dir: string): void { Bright.step(dir === "down" ? -1 : 1) }   // up | down
        function updates(): void { Updates.finished() }   // re-check pending updates (the upgrade terminal calls it)
    }
}
