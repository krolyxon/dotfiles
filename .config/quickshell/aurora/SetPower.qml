import QtQuick
import QtQuick.Layouts

// Settings app > Power: battery, graphics mode, idle timeouts (hypridle via Idle) and caffeine.
Flickable {
    id: flick
    clip: true
    contentWidth: width
    contentHeight: col.implicitHeight
    boundsBehavior: Flickable.StopAtBounds

    // seconds -> "2m 30s" / "never"
    function dur(s) {
        if (s <= 0) return "never"
        var m = Math.floor(s / 60), r = s % 60
        return m > 0 ? m + "m" + (r ? " " + r + "s" : "") : r + "s"
    }

    // one timeout row: slider in 30s steps (0 = never) + readable value
    component Timeout: RowLayout {
        id: t
        property string label: ""
        property string key: ""
        property int value: 0
        property int max: 1800
        Layout.fillWidth: true
        spacing: 8
        Text {
            Layout.preferredWidth: 150
            text: t.label
            color: Theme.fg
            font.family: Theme.font
            font.pixelSize: Theme.fontSize
        }
        BarSlider {
            Layout.fillWidth: true
            from: 0
            to: t.max
            step: 30 / t.max
            value: t.value
            onMoved: v => Idle.setTimeout(t.key, Math.round(v / 30) * 30)
        }
        Text {
            Layout.preferredWidth: 70
            horizontalAlignment: Text.AlignRight
            text: flick.dur(t.value)
            color: t.value > 0 ? Theme.fg : Theme.dim
            font.family: Theme.font
            font.pixelSize: Theme.fontSize
        }
    }

    ColumnLayout {
        id: col
        width: flick.width
        spacing: 8

        BatteryInfo {}
        GpuSwitch { Layout.topMargin: 6 }

        SectionLabel { text: "when idle"; Layout.topMargin: 6 }
        Timeout { label: "dim the screen"; key: "idleDim"; value: Idle.dim }
        Timeout { label: "screen off"; key: "idleOff"; value: Idle.screenOff }
        Timeout { label: "lock"; key: "idleLock"; value: Idle.lock }
        Timeout { label: "suspend"; key: "idleSuspend"; value: Idle.suspend; max: 3600 }
        Switch {
            label: "caffeine"
            hint: "keep the screen awake until turned off (not saved)"
            checked: Toggles.caffeine
            onToggled: on => Toggles.caffeine = on
        }
        Text {
            Layout.fillWidth: true
            text: "saved to ~/.config/aurora/hypridle.conf, hypridle restarts on change"
            color: Theme.dim
            elide: Text.ElideLeft
            font.family: Theme.font
            font.pixelSize: Theme.fontSize - 2
        }
    }
}
