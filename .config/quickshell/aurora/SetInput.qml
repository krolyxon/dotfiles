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
            visible: HyprConf.message !== ""
            text: HyprConf.message
            color: Theme.err
            wrapMode: Text.WordWrap
            font.family: Theme.font
            font.pixelSize: Theme.fontSize - 1
        }

        SectionLabel { text: "keyboard" }
        Field { label: "layouts"; placeholder: "us,de"; value: flick.v("input:kb_layout", ""); onSubmitted: x => HyprConf.set("input:kb_layout", x) }
        Field { label: "variants"; placeholder: "(none)"; value: flick.v("input:kb_variant", ""); onSubmitted: x => HyprConf.set("input:kb_variant", x) }
        Field { label: "xkb options"; placeholder: "grp:alt_shift_toggle"; value: flick.v("input:kb_options", ""); onSubmitted: x => HyprConf.set("input:kb_options", x) }
        Knob { label: "repeat rate"; unit: "/s"; from: 10; to: 100; value: flick.v("input:repeat_rate", 25); onMoved: x => HyprConf.set("input:repeat_rate", x) }
        Knob { label: "repeat delay"; unit: "ms"; from: 150; to: 1000; value: flick.v("input:repeat_delay", 600); onMoved: x => HyprConf.set("input:repeat_delay", Math.round(x / 10) * 10) }

        SectionLabel { text: "mouse" }
        Knob { label: "sensitivity"; from: -1; to: 1; decimals: 2; value: flick.v("input:sensitivity", 0); onMoved: x => HyprConf.set("input:sensitivity", x) }
        Choice {
            label: "acceleration"
            options: [{ value: "", label: "default" }, { value: "flat", label: "flat" }, { value: "adaptive", label: "adaptive" }]
            value: flick.v("input:accel_profile", "")
            onPicked: x => HyprConf.set("input:accel_profile", x)
        }
        Choice {
            label: "focus follows mouse"
            options: [{ value: 0, label: "off" }, { value: 1, label: "always" }, { value: 2, label: "loose" }, { value: 3, label: "hover only" }]
            value: flick.v("input:follow_mouse", -1)
            onPicked: x => HyprConf.set("input:follow_mouse", x)
        }
        Switch { label: "natural scroll"; checked: flick.v("input:natural_scroll", false); onToggled: on => HyprConf.set("input:natural_scroll", on) }
        Switch { label: "left handed"; checked: flick.v("input:left_handed", false); onToggled: on => HyprConf.set("input:left_handed", on) }

        SectionLabel { text: "touchpad" }
        Switch { label: "natural scroll"; checked: flick.v("input:touchpad:natural_scroll", false); onToggled: on => HyprConf.set("input:touchpad:natural_scroll", on) }
        Switch { label: "tap to click"; checked: flick.v("input:touchpad:tap_to_click", false); onToggled: on => HyprConf.set("input:touchpad:tap_to_click", on) }
        Switch { label: "disable while typing"; checked: flick.v("input:touchpad:disable_while_typing", false); onToggled: on => HyprConf.set("input:touchpad:disable_while_typing", on) }
        Knob { label: "scroll speed"; from: 0.1; to: 3; decimals: 2; value: flick.v("input:touchpad:scroll_factor", 1); onMoved: x => HyprConf.set("input:touchpad:scroll_factor", x) }

        SectionLabel { text: "cursor" }
        Knob { label: "hide when idle"; unit: "s"; from: 0; to: 30; value: flick.v("cursor:inactive_timeout", 0); onMoved: x => HyprConf.set("cursor:inactive_timeout", x) }
        Switch { label: "hide while typing"; checked: flick.v("cursor:hide_on_key_press", false); onToggled: on => HyprConf.set("cursor:hide_on_key_press", on) }

        Item { Layout.preferredHeight: 6 }
        RowLayout {
            Layout.fillWidth: true
            Text {
                Layout.fillWidth: true
                text: "per-device settings (hl.device) stay in source/input.lua"
                elide: Text.ElideRight
                color: Theme.dim
                font.family: Theme.font
                font.pixelSize: Theme.fontSize - 2
            }
            IconBtn { icon: Theme.iRefresh; label: "reset to config"; onClicked: HyprConf.resetAll(["input:", "cursor:"]) }
        }
    }
}
