import QtQuick
import QtQuick.Layouts
import Quickshell.Services.UPower

// Settings app > Power: battery + battery care (Battery), power profile, graphics mode, idle timeouts (hypridle via Idle) and caffeine.
Flickable {
    id: flick
    clip: true
    contentWidth: width
    contentHeight: col.implicitHeight
    boundsBehavior: Flickable.StopAtBounds

    readonly property var profiles: [{ value: "saver", label: "saver" }, { value: "balanced", label: "balanced" }]
        .concat(Battery.hasPerf ? [{ value: "performance", label: "performance" }] : [])

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

        SectionLabel { text: "battery care"; Layout.topMargin: 6; visible: Battery.hasBat }
        Choice {
            visible: Battery.supported
            label: "charge limit"
            options: [{ value: "off", label: "off" }, { value: "conservation", label: "conservation" }]
            value: Settings.chargeMode === "off" ? "off" : "conservation"
            onPicked: v => Settings.chargeMode = v
        }
        Text {
            visible: Battery.supported
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            text: Settings.chargeMode !== "off"
                  ? "the firmware stops charging at ~80%, even when aurora isn't running. Conservation mode is "
                    + (Battery.capOn ? "on" : "off") + "."
                  : "charges to 100%"
            color: Theme.dim
            font.family: Theme.font
            font.pixelSize: Theme.fontSize - 2
        }
        Knob {
            visible: Battery.hasBat
            label: "warn at"
            from: 5; to: 40; unit: "%"
            value: Settings.batLow
            onMoved: v => Settings.batLow = v
        }
        Knob {
            visible: Battery.hasBat
            label: "critical at"
            from: 2; to: 15; unit: "%"
            value: Settings.batCritical
            onMoved: v => Settings.batCritical = v
        }
        Choice {
            visible: Battery.hasBat
            label: "when critical"
            options: [{ value: "none", label: "warn" }, { value: "suspend", label: "suspend" },
                      { value: "poweroff", label: "power off" }]
            value: Settings.batCriticalAction
            onPicked: v => Settings.batCriticalAction = v
        }

        Choice {
            Layout.topMargin: 6
            visible: Battery.hasProfiles
            label: "power profile"
            options: flick.profiles.concat(Battery.hasBat ? [{ value: "auto", label: "auto" }] : [])
            value: Battery.profile
            onPicked: v => Battery.setProfile(v)
        }
        Choice {
            visible: Battery.hasProfiles && Settings.powerAuto
            label: "on AC"
            options: flick.profiles
            value: Settings.powerAc
            onPicked: v => Settings.powerAc = v
        }
        Choice {
            visible: Battery.hasProfiles && Settings.powerAuto
            label: "on battery"
            options: flick.profiles
            value: Settings.powerBat
            onPicked: v => Settings.powerBat = v
        }
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
