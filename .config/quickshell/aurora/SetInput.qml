import QtQuick
import QtQuick.Layouts

// Settings app > Input: keyboard, mouse, touchpad, cursor, through HyprConf (live + persisted).
Flickable {
    id: flick
    clip: true
    contentWidth: width
    contentHeight: col.implicitHeight
    boundsBehavior: Flickable.StopAtBounds

    Component.onCompleted: HyprConf.refresh()
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

        SectionLabel { text: "keyboard"; keywords: "xkb typing" }
        Field { label: "layouts"; keywords: "keyboard layout language kb_layout"; placeholder: "us,de"; value: flick.v("input:kb_layout", ""); onSubmitted: x => HyprConf.set("input:kb_layout", x) }
        Field { label: "variants"; keywords: "keyboard variant dvorak colemak"; placeholder: "(none)"; value: flick.v("input:kb_variant", ""); onSubmitted: x => HyprConf.set("input:kb_variant", x) }
        Field { label: "xkb options"; keywords: "caps lock compose kb_options"; placeholder: "grp:alt_shift_toggle"; value: flick.v("input:kb_options", ""); onSubmitted: x => HyprConf.set("input:kb_options", x) }
        Knob { label: "repeat rate"; keywords: "key repeat speed"; unit: "/s"; from: 10; to: 100; value: flick.v("input:repeat_rate", 25); onMoved: x => HyprConf.set("input:repeat_rate", x) }
        Knob { label: "repeat delay"; keywords: "key repeat"; unit: "ms"; from: 150; to: 1000; value: flick.v("input:repeat_delay", 600); onMoved: x => HyprConf.set("input:repeat_delay", Math.round(x / 10) * 10) }

        SectionLabel { text: "mouse"; keywords: "pointer" }
        Knob { label: "sensitivity"; keywords: "mouse speed pointer"; from: -1; to: 1; decimals: 2; value: flick.v("input:sensitivity", 0); onMoved: x => HyprConf.set("input:sensitivity", x) }
        Choice {
            label: "acceleration"
            keywords: "mouse accel"
            options: [{ value: "", label: "default" }, { value: "flat", label: "flat" }, { value: "adaptive", label: "adaptive" }]
            value: flick.v("input:accel_profile", "")
            onPicked: x => HyprConf.set("input:accel_profile", x)
        }
        Choice {
            label: "focus follows mouse"
            keywords: "focus hover"
            options: [{ value: 0, label: "off" }, { value: 1, label: "always" }, { value: 2, label: "loose" }, { value: 3, label: "hover only" }]
            value: flick.v("input:follow_mouse", -1)
            onPicked: x => HyprConf.set("input:follow_mouse", x)
        }
        Switch { label: "natural scroll"; keywords: "reverse scrolling"; checked: flick.v("input:natural_scroll", false); onToggled: on => HyprConf.set("input:natural_scroll", on) }
        Switch { label: "left handed"; keywords: "swap buttons"; checked: flick.v("input:left_handed", false); onToggled: on => HyprConf.set("input:left_handed", on) }

        SectionLabel { text: "touchpad"; keywords: "trackpad" }
        Switch { label: "natural scroll"; keywords: "reverse scrolling"; checked: flick.v("input:touchpad:natural_scroll", false); onToggled: on => HyprConf.set("input:touchpad:natural_scroll", on) }
        Switch { label: "tap to click"; keywords: "tap"; checked: flick.v("input:touchpad:tap_to_click", false); onToggled: on => HyprConf.set("input:touchpad:tap_to_click", on) }
        Switch { label: "disable while typing"; keywords: "palm rejection dwt"; checked: flick.v("input:touchpad:disable_while_typing", false); onToggled: on => HyprConf.set("input:touchpad:disable_while_typing", on) }
        Knob { label: "scroll speed"; keywords: "scroll factor"; from: 0.1; to: 3; decimals: 2; value: flick.v("input:touchpad:scroll_factor", 1); onMoved: x => HyprConf.set("input:touchpad:scroll_factor", x) }

        SectionLabel { text: "gestures"; keywords: "swipe touchpad fingers" }
        Switch { label: "invert swipe"; hint: "reverse the 3-finger workspace swipe"; checked: flick.v("gestures:workspace_swipe_invert", true); onToggled: on => HyprConf.set("gestures:workspace_swipe_invert", on) }
        Knob { label: "swipe distance"; unit: "px"; from: 100; to: 1000; value: flick.v("gestures:workspace_swipe_distance", 300); onMoved: x => HyprConf.set("gestures:workspace_swipe_distance", Math.round(x / 10) * 10) }

        SectionLabel { text: "cursor"; keywords: "mouse pointer" }
        Knob { label: "hide when idle"; keywords: "cursor inactive timeout"; unit: "s"; from: 0; to: 30; value: flick.v("cursor:inactive_timeout", 0); onMoved: x => HyprConf.set("cursor:inactive_timeout", x) }
        Switch { label: "hide while typing"; keywords: "cursor"; checked: flick.v("cursor:hide_on_key_press", false); onToggled: on => HyprConf.set("cursor:hide_on_key_press", on) }

        Item { Layout.preferredHeight: 6 }
        RowLayout {
            Layout.fillWidth: true
            Text {
                Layout.fillWidth: true
                Layout.leftMargin: 18
                text: "per-device settings (hl.device) stay in source/input.lua"
                elide: Text.ElideRight
                color: Theme.fgDim
                font.family: Theme.ui
                font.pixelSize: 13
            }
            IconBtn { icon: Theme.iRefresh; label: "reset to config"; keywords: "reset defaults restore hyprland"; onClicked: HyprConf.resetAll(["input:", "cursor:", "gestures:"]) }
        }
    }
}
