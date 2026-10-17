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

    function addr(a) { a = String(a); return a.indexOf("0x") === 0 ? a : "0x" + a }

    function focusWindow(a) {
        if (luaSyntax)
            Quickshell.execDetached(["hyprctl", "dispatch", 'hl.dsp.focus({window="address:' + addr(a) + '"})'])
        else
            Quickshell.execDetached(["hyprctl", "dispatch", "focuswindow", "address:" + addr(a)])
    }
    // window.move ignores an unknown `window=` key (returns ok and moves the active window instead),
    // so focus the target first and then move the active one
    function moveWindow(a, ws) {
        if (luaSyntax)
            Quickshell.execDetached(["hyprctl", "--batch",
                'dispatch hl.dsp.focus({window="address:' + addr(a) + '"}); dispatch hl.dsp.window.move({workspace=' + Number(ws) + '})'])
        else
            Quickshell.execDetached(["hyprctl", "dispatch", "movetoworkspacesilent", Number(ws) + ",address:" + addr(a)])
    }

    // compositor-agnostic logout
    function logout() { Quickshell.execDetached(["sh", "-c", 'loginctl terminate-user "$USER"']) }
}
