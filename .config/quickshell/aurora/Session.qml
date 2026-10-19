pragma Singleton
import QtQuick
import Quickshell

// Session / power actions shared by PowerMenu and Runner. `confirm` ones need the two-press "sure?" arm.
Singleton {
    readonly property var actions: [
        { id: "lock",      icon: Theme.iLock,      label: "lock",           confirm: false },
        { id: "leave",     icon: Theme.iLogout,    label: "leave Hyprland", confirm: true },
        { id: "renew",     icon: Theme.iRefresh,   label: "renew Hyprland", confirm: false },
        { id: "hibernate", icon: Theme.iHibernate, label: "hibernate",      confirm: true },
        { id: "reboot",    icon: Theme.iReboot,    label: "reboot",         confirm: true },
        { id: "shutdown",  icon: Theme.iPower,     label: "shutdown",       confirm: true },
        { id: "sleep",     icon: Theme.iSleep,     label: "sleep",          confirm: false },
        { id: "display",   icon: Theme.iMonitor,   label: "display off",    confirm: false }
    ]

    function run(id) {
        switch (id) {
        case "lock":      Quickshell.execDetached(["loginctl", "lock-session"]); break
        case "leave":     Hypr.logout(); break
        case "renew":     Quickshell.execDetached(["hyprctl", "reload"]); break
        case "hibernate": Quickshell.execDetached(["systemctl", "hibernate", "-i"]); break
        case "reboot":    Quickshell.execDetached(["systemctl", "reboot", "-i"]); break
        case "shutdown":  Quickshell.execDetached(["systemctl", "poweroff", "-i"]); break
        case "sleep":     Quickshell.execDetached(["systemctl", "suspend", "-i"]); break
        case "display":   dpmsDelay.restart(); break   // let the Enter key-up pass first, it would wake the screen
        }
    }
    Timer {
        id: dpmsDelay
        interval: 400
        onTriggered: Quickshell.execDetached(["hyprctl", "dispatch", 'hl.dsp.dpms({action="off"})'])
    }
}
