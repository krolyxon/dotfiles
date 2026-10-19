pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Hyprland options edited from the settings app. Only what the user changed is stored, as overrides:
//   ~/.config/aurora/hypr.json  {"general:gaps_in": 5, ...}       (state, read back here)
//   ~/.config/aurora/hypr.lua   return { general = { gaps_in = 5 } }  (dofile'd at the end of hyprland.lua)
// A change is applied live with `hyprctl eval 'hl.config({...})'` and survives reloads/logins through hypr.lua.
// reset(opt) drops the override and reloads Hyprland's config, so the repo value comes back.
Singleton {
    id: root
    readonly property string dir: Quickshell.env("HOME") + "/.config/aurora"

    // every option the settings pages show: path -> type (int | float | bool | str)
    readonly property var types: ({
        "general:gaps_in": "int", "general:gaps_out": "int", "general:border_size": "int",
        "general:layout": "str", "general:resize_on_border": "bool",
        "decoration:rounding": "int", "decoration:active_opacity": "float", "decoration:inactive_opacity": "float",
        "decoration:dim_inactive": "bool", "decoration:shadow:enabled": "bool",
        "decoration:blur:enabled": "bool", "decoration:blur:size": "int", "decoration:blur:passes": "int",
        "decoration:blur:xray": "bool",
        "animations:enabled": "bool",
        "master:mfact": "float", "master:new_status": "str", "master:new_on_top": "bool", "master:orientation": "str",
        "dwindle:preserve_split": "bool", "dwindle:smart_split": "bool",
        "misc:on_focus_under_fullscreen": "int", "misc:exit_window_retains_fullscreen": "bool",
        "misc:focus_on_activate": "bool",
        "input:kb_layout": "str", "input:kb_variant": "str", "input:kb_options": "str",
        "input:repeat_rate": "int", "input:repeat_delay": "int", "input:sensitivity": "float",
        "input:accel_profile": "str", "input:follow_mouse": "int", "input:natural_scroll": "bool",
        "input:left_handed": "bool",
        "input:touchpad:natural_scroll": "bool", "input:touchpad:tap_to_click": "bool",
        "input:touchpad:disable_while_typing": "bool", "input:touchpad:scroll_factor": "float",
        "cursor:inactive_timeout": "int", "cursor:hide_on_key_press": "bool"
    })

    property var values: ({})        // current value of every option in `types` (from getoption)
    property var overrides: ({})     // only the changed ones
    property string message: ""      // last hyprctl error, shown by the pages
    property bool loaded: false

    function get(opt) { return values[opt] }
    function isSet(opt) { return overrides.hasOwnProperty(opt) }

    function set(opt, v) {
        if (!types.hasOwnProperty(opt)) return
        var o = Object.assign({}, overrides), c = Object.assign({}, values)
        o[opt] = v
        c[opt] = v
        overrides = o
        values = c
        pending[opt] = v
        applyTimer.restart()          // coalesces slider drags into one hyprctl call
        saveTimer.restart()
    }
    function reset(opt) {
        if (!isSet(opt)) return
        var o = Object.assign({}, overrides)
        delete o[opt]
        overrides = o
        save()
        reloadProc.running = true     // config-only reload re-reads the repo files + the new hypr.lua
    }
    function resetAll(prefixes) {     // e.g. ["input:"]: reset every override under those sections
        var o = Object.assign({}, overrides), changed = false
        for (var k in o)
            for (var i = 0; i < prefixes.length; i++)
                if (k.indexOf(prefixes[i]) === 0) { delete o[k]; changed = true; break }
        if (!changed) return
        overrides = o
        save()
        reloadProc.running = true
    }
    function refresh() {
        readProc.command = ["sh", "-c", 'for o; do hyprctl -j getoption "$o" | tr -d "\\n"; echo; done', "sh"]
            .concat(Object.keys(types))
        readProc.running = true
    }

    // ---- lua generation: keys only ever come from `types`, values are typed + escaped ----
    function luaValue(opt, v) {
        var t = types[opt]
        if (t === "bool") return v ? "true" : "false"
        if (t === "int") return String(Math.round(Number(v)) || 0)
        if (t === "float") { var n = Number(v); return String(isFinite(n) ? n : 0) }
        return '"' + String(v).replace(/\\/g, "\\\\").replace(/"/g, '\\"').replace(/[\r\n]/g, " ") + '"'
    }
    function luaTable(map) {          // {"a:b:c": v} -> "{ a = { b = { c = v } } }"
        var tree = {}
        for (var opt in map) {
            if (!types.hasOwnProperty(opt)) continue
            var parts = opt.split(":"), node = tree
            for (var i = 0; i < parts.length - 1; i++) {
                if (typeof node[parts[i]] !== "object") node[parts[i]] = {}
                node = node[parts[i]]
            }
            node[parts[parts.length - 1]] = { lua: luaValue(opt, map[opt]) }
        }
        function emit(n, ind) {
            var keys = Object.keys(n).sort(), out = []
            for (var j = 0; j < keys.length; j++) {
                var x = n[keys[j]]
                out.push(ind + "    " + keys[j] + " = " + (x.hasOwnProperty("lua") ? x.lua : emit(x, ind + "    ")))
            }
            return out.length ? "{\n" + out.join(",\n") + "\n" + ind + "}" : "{}"
        }
        return emit(tree, "")
    }

    function save() {
        jsonFile.setText(JSON.stringify(overrides, null, 2) + "\n")
        luaFile.setText("-- generated by aurora's settings app (HyprConf.qml); edit there, not here\n"
            + "return " + luaTable(overrides) + "\n")
    }

    property var pending: ({})
    Timer {
        id: applyTimer
        interval: 60
        onTriggered: {
            var code = "hl.config(" + root.luaTable(root.pending) + ")"
            root.pending = {}
            applyProc.command = ["hyprctl", "eval", code]
            applyProc.running = true
        }
    }
    Timer { id: saveTimer; interval: 400; onTriggered: root.save() }

    Process {
        id: applyProc
        stdout: StdioCollector {
            onStreamFinished: root.message = text.trim() === "ok" || text.trim() === "" ? "" : text.trim()
        }
    }
    Process {
        id: reloadProc
        command: ["hyprctl", "reload", "config-only"]
        onExited: root.refresh()
    }
    Process {
        id: readProc
        stdout: StdioCollector {
            onStreamFinished: {
                var c = {}, lines = text.split("\n")
                for (var i = 0; i < lines.length; i++) {
                    if (lines[i].trim() === "") continue
                    try {
                        var j = JSON.parse(lines[i]), v
                        if (j.hasOwnProperty("css")) v = parseInt(String(j.css).split(" ")[0])   // gaps: "2 2 2 2"
                        else if (j.hasOwnProperty("int")) v = j.int
                        else if (j.hasOwnProperty("float")) v = j.float
                        else if (j.hasOwnProperty("bool")) v = j.bool
                        else if (j.hasOwnProperty("str")) v = j.str === "[[EMPTY]]" ? "" : j.str   // unset string option
                        if (v !== undefined) c[j.option] = root.types[j.option] === "bool" ? !!v : v
                    } catch (e) {}
                }
                root.values = c
                root.loaded = true
            }
        }
    }

    FileView {
        id: jsonFile
        path: root.dir + "/hypr.json"
        blockLoading: true
        printErrors: false      // no file until the first change
        onLoaded: {
            try { root.overrides = JSON.parse(text()) || {} } catch (e) { root.overrides = {} }
        }
    }
    FileView { id: luaFile; path: root.dir + "/hypr.lua"; preload: false; printErrors: false }   // write-only

    Component.onCompleted: refresh()
}
