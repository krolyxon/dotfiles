import QtQuick
import QtQuick.Layouts

// Settings app > Windows: Hyprland look + layout + fullscreen behaviour, through HyprConf (live + persisted).
Flickable {
    id: flick
    clip: true
    contentWidth: width
    contentHeight: col.implicitHeight
    boundsBehavior: Flickable.StopAtBounds

    Component.onCompleted: HyprConf.refresh()
    // current value, or d while getoption hasn't answered yet
    function v(o, d) { var x = HyprConf.values[o]; return x === undefined ? d : x }

    ColumnLayout {
        id: col
        width: flick.width
        spacing: 8

        Text {
            Layout.fillWidth: true
            Layout.leftMargin: 18
            visible: HyprConf.message !== ""
            text: HyprConf.message
            color: Theme.err
            wrapMode: Text.WordWrap
            font.family: Theme.ui
            font.pixelSize: 14
        }

        SectionLabel { text: "gaps & borders" }
        Knob { label: "inner gaps"; unit: "px"; from: 0; to: 30; value: flick.v("general:gaps_in", 0); onMoved: x => HyprConf.set("general:gaps_in", x) }
        Knob { label: "outer gaps"; unit: "px"; from: 0; to: 40; value: flick.v("general:gaps_out", 0); onMoved: x => HyprConf.set("general:gaps_out", x) }
        Knob { label: "border"; unit: "px"; from: 0; to: 8; value: flick.v("general:border_size", 0); onMoved: x => HyprConf.set("general:border_size", x) }
        Knob { label: "rounding"; unit: "px"; from: 0; to: 20; value: flick.v("decoration:rounding", 0); onMoved: x => HyprConf.set("decoration:rounding", x) }
        Switch { label: "resize on border"; hint: "drag window edges to resize"; checked: flick.v("general:resize_on_border", false); onToggled: on => HyprConf.set("general:resize_on_border", on) }

        SectionLabel { text: "opacity" }
        Knob { label: "focused"; from: 0.3; to: 1; decimals: 2; value: flick.v("decoration:active_opacity", 1); onMoved: x => HyprConf.set("decoration:active_opacity", x) }
        Knob { label: "unfocused"; from: 0.3; to: 1; decimals: 2; value: flick.v("decoration:inactive_opacity", 1); onMoved: x => HyprConf.set("decoration:inactive_opacity", x) }
        Switch { label: "dim unfocused"; checked: flick.v("decoration:dim_inactive", false); onToggled: on => HyprConf.set("decoration:dim_inactive", on) }

        SectionLabel { text: "effects" }
        Switch { label: "blur"; hint: "behind transparent windows and layers"; checked: flick.v("decoration:blur:enabled", false); onToggled: on => HyprConf.set("decoration:blur:enabled", on) }
        Knob { label: "blur size"; from: 1; to: 15; value: flick.v("decoration:blur:size", 1); onMoved: x => HyprConf.set("decoration:blur:size", x) }
        Knob { label: "blur passes"; from: 1; to: 6; value: flick.v("decoration:blur:passes", 1); onMoved: x => HyprConf.set("decoration:blur:passes", x) }
        Switch { label: "blur x-ray"; hint: "floating windows blur the wallpaper, not what's under them"; checked: flick.v("decoration:blur:xray", false); onToggled: on => HyprConf.set("decoration:blur:xray", on) }
        Switch { label: "shadows"; checked: flick.v("decoration:shadow:enabled", false); onToggled: on => HyprConf.set("decoration:shadow:enabled", on) }
        Switch { label: "animations"; checked: flick.v("animations:enabled", false); onToggled: on => HyprConf.set("animations:enabled", on) }

        SectionLabel { text: "layout" }
        Choice {
            label: "tiling layout"
            options: [{ value: "master", label: "master" }, { value: "dwindle", label: "dwindle" }]
            value: flick.v("general:layout", "")
            onPicked: x => HyprConf.set("general:layout", x)
        }
        ColumnLayout {
            Layout.fillWidth: true
            visible: flick.v("general:layout", "") === "master"
            spacing: 8
            Knob { label: "master width"; from: 0.1; to: 0.9; decimals: 2; value: flick.v("master:mfact", 0.55); onMoved: x => HyprConf.set("master:mfact", x) }
            Choice {
                label: "new window"
                options: [{ value: "master", label: "master" }, { value: "slave", label: "stack" }, { value: "inherit", label: "inherit" }]
                value: flick.v("master:new_status", "")
                onPicked: x => HyprConf.set("master:new_status", x)
            }
            Choice {
                label: "master side"
                options: [{ value: "left", label: "left" }, { value: "right", label: "right" }, { value: "top", label: "top" },
                          { value: "bottom", label: "bottom" }, { value: "center", label: "center" }]
                value: flick.v("master:orientation", "")
                onPicked: x => HyprConf.set("master:orientation", x)
            }
            Switch { label: "new windows on top of the stack"; checked: flick.v("master:new_on_top", false); onToggled: on => HyprConf.set("master:new_on_top", on) }
        }
        ColumnLayout {
            Layout.fillWidth: true
            visible: flick.v("general:layout", "") === "dwindle"
            spacing: 8
            Switch { label: "preserve split"; hint: "keep the split direction when windows move"; checked: flick.v("dwindle:preserve_split", false); onToggled: on => HyprConf.set("dwindle:preserve_split", on) }
            Switch { label: "smart split"; hint: "split by where the cursor is"; checked: flick.v("dwindle:smart_split", false); onToggled: on => HyprConf.set("dwindle:smart_split", on) }
        }

        SectionLabel { text: "fullscreen & focus" }
        Choice {
            label: "focus under fullscreen"
            options: [{ value: 0, label: "ignore" }, { value: 1, label: "take over" }, { value: 2, label: "exit fullscreen" }]
            value: flick.v("misc:on_focus_under_fullscreen", -1)
            onPicked: x => HyprConf.set("misc:on_focus_under_fullscreen", x)
        }
        Switch { label: "closing keeps fullscreen"; hint: "the next window takes over when the fullscreen one closes (dwm monocle)"; checked: flick.v("misc:exit_window_retains_fullscreen", false); onToggled: on => HyprConf.set("misc:exit_window_retains_fullscreen", on) }
        Switch { label: "focus on activate"; hint: "apps asking for attention get focused"; checked: flick.v("misc:focus_on_activate", false); onToggled: on => HyprConf.set("misc:focus_on_activate", on) }

        Item { Layout.preferredHeight: 6 }
        RowLayout {
            Layout.fillWidth: true
            Text {
                Layout.fillWidth: true
                Layout.leftMargin: 18
                text: "saved to ~/.config/aurora/hypr.lua (loaded last by hyprland.lua)"
                elide: Text.ElideLeft
                color: Theme.fgDim
                font.family: Theme.ui
                font.pixelSize: 13
            }
            IconBtn {
                icon: Theme.iRefresh
                label: "reset to config"
                onClicked: HyprConf.resetAll(["general:", "decoration:", "animations:", "master:", "dwindle:", "misc:"])
            }
        }
    }
}
