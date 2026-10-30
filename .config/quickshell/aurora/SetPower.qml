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
    // one timeout row, like a Knob: slider in 30s steps (0 = never) + the readable value in a chip
    component Timeout: RowLayout {
        id: t
        property string label: ""
        property string keywords: ""
        property string key: ""
        property int value: 0
        property int max: 1800
        Layout.fillWidth: true
        Layout.leftMargin: 18
        Layout.rightMargin: 14
        implicitHeight: 48
        spacing: 16
        Text {
            Layout.preferredWidth: 200
            text: t.label
            color: Theme.fg
            font.family: Theme.ui
            font.pixelSize: 15
        }
        BarSlider {
            Layout.fillWidth: true
            from: 0
            to: t.max
            step: 30 / t.max
            value: t.value
            onMoved: v => Idle.setTimeout(t.key, Math.round(v / 30) * 30)
        }
        Rectangle {
            Layout.preferredWidth: 76
            implicitHeight: 32
            radius: 16
            color: Theme.s2
            Lb {
                anchors.centerIn: parent
                text: flick.dur(t.value)
                color: t.value > 0 ? Theme.fg : Theme.grey
            }
        }
    }

    ColumnLayout {
        id: col
        width: flick.width
        spacing: 8

        BatteryInfo {}

        SectionLabel { text: "battery care"; keywords: "battery health"; Layout.topMargin: 6; visible: Battery.hasBat }
        Choice {
            visible: Battery.supported
            label: "charge limit"
            keywords: "conservation 80% battery health longevity"
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
            color: Theme.fgDim
            font.family: Theme.ui
            font.pixelSize: 13
        }
        Knob {
            visible: Battery.hasBat
            label: "warn at"
            keywords: "low battery warning"
            from: 5; to: 40; unit: "%"
            value: Settings.batLow
            onMoved: v => Settings.batLow = v
        }
        Knob {
            visible: Battery.hasBat
            label: "critical at"
            keywords: "critical battery"
            from: 2; to: 15; unit: "%"
            value: Settings.batCritical
            onMoved: v => Settings.batCritical = v
        }
        Choice {
            visible: Battery.hasBat
            label: "when critical"
            keywords: "low battery action"
            options: [{ value: "none", label: "warn" }, { value: "suspend", label: "suspend" },
                      { value: "poweroff", label: "power off" }]
            value: Settings.batCriticalAction
            onPicked: v => Settings.batCriticalAction = v
        }

        Choice {
            Layout.topMargin: 6
            visible: Battery.hasProfiles
            label: "power profile"
            keywords: "performance balanced saver power-profiles-daemon"
            options: flick.profiles.concat(Battery.hasBat ? [{ value: "auto", label: "auto" }] : [])
            value: Battery.profile
            onPicked: v => Battery.setProfile(v)
        }
        Choice {
            visible: Battery.hasProfiles && Settings.powerAuto
            label: "on AC"
            keywords: "plugged in charger power profile"
            options: flick.profiles
            value: Settings.powerAc
            onPicked: v => Settings.powerAc = v
        }
        Choice {
            visible: Battery.hasProfiles && Settings.powerAuto
            label: "on battery"
            keywords: "unplugged power profile"
            options: flick.profiles
            value: Settings.powerBat
            onPicked: v => Settings.powerBat = v
        }
        GpuSwitch { Layout.topMargin: 6 }

        SectionLabel { text: "when idle"; keywords: "idle timeout sleep hypridle"; Layout.topMargin: 6 }
        Timeout { label: "dim the screen"; keywords: "idle dim timeout"; key: "idleDim"; value: Idle.dim }
        Timeout { label: "screen off"; keywords: "dpms display off idle timeout"; key: "idleOff"; value: Idle.screenOff }
        Timeout { label: "lock"; keywords: "lock screen hyprlock idle timeout"; key: "idleLock"; value: Idle.lock }
        Timeout { label: "suspend"; keywords: "sleep idle timeout"; key: "idleSuspend"; value: Idle.suspend; max: 3600 }
        Switch {
            label: "caffeine"
            keywords: "stay awake keep awake inhibit idle"
            hint: "keep the screen awake until turned off (not saved)"
            checked: Toggles.caffeine
            onToggled: on => Toggles.caffeine = on
        }
        Text {
            Layout.fillWidth: true
            Layout.leftMargin: 18
            text: "saved to ~/.config/aurora/hypridle.conf, hypridle restarts on change"
            color: Theme.fgDim
            elide: Text.ElideLeft
            font.family: Theme.ui
            font.pixelSize: 13
        }
    }
}
