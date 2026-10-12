pragma Singleton
import QtQuick
import Quickshell

// Compositor actions. Your waybar config uses the new Lua-style dispatchers
// (hl.dsp.focus{...}), so that is the default; flip luaSyntax for older Hyprland.
Singleton {
    property bool luaSyntax: true

    function workspace(arg) {
        if (luaSyntax)
            Quickshell.execDetached(["hyprctl", "dispatch", 'hl.dsp.focus({workspace="' + arg + '"})'])
        else
            Quickshell.execDetached(["hyprctl", "dispatch", "workspace", String(arg)])
    }

    // compositor-agnostic logout
    function logout() { Quickshell.execDetached(["sh", "-c", 'loginctl terminate-user "$USER"']) }
}
