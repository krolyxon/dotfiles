import QtQuick
import QtQuick.Layouts
import Quickshell.Services.UPower

// Battery block (SysPage, settings app > Power): charge in Doto, state, a segment bar (accent when low), details.
// After glyph-rice's battery card (github.com/Nebelung-cloud/glyph-rice, GPL-3.0), bar/Bar.qml.
ColumnLayout {
    id: root
    readonly property var bat: UPower.displayDevice
    readonly property bool hasBat: bat !== null && bat.isPresent
    readonly property real batPct: hasBat ? (bat.percentage > 1 ? bat.percentage / 100 : bat.percentage) : 0
    readonly property bool charging: hasBat && bat.state === UPowerDeviceState.Charging
    readonly property bool low: batPct <= Settings.batLow / 100 && !charging
    function stateLine() {
        if (!hasBat) return ""
        switch (bat.state) {
        case UPowerDeviceState.Charging:
            return "charging" + (bat.timeToFull > 0 ? " · full in " + Theme.fmtTime(bat.timeToFull) : "")
        case UPowerDeviceState.Discharging:
            return "on battery" + (bat.timeToEmpty > 0 ? " · " + Theme.fmtTime(bat.timeToEmpty) + " left" : "")
        case UPowerDeviceState.FullyCharged: return "on ac · full"
        default: return UPower.onBattery ? "on battery" : "on ac · not charging"
        }
    }
    visible: hasBat
    Layout.fillWidth: true
    spacing: 12

    SectionLabel { text: "battery"; keywords: "charge level percentage health time left" }
    RowLayout {
        Layout.leftMargin: 6
        spacing: 14
        Num {
            text: Math.round(root.batPct * 100)
            font.pixelSize: 56
        }
        ColumnLayout {
            spacing: 6
            Lb { text: "% battery"; color: Theme.fg }
            Lb { text: root.stateLine() }
        }
    }
    Seg {
        Layout.fillWidth: true
        Layout.preferredWidth: 100
        Layout.preferredHeight: 6
        Layout.leftMargin: 6
        Layout.rightMargin: 6
        n: 24
        f: root.batPct
        on: root.low ? Theme.err : Theme.fill
    }
    Lb {
        Layout.fillWidth: true
        Layout.leftMargin: 6
        wrapMode: Text.Wrap
        lineHeight: 1.5
        px: 10
        text: {
            if (!root.hasBat) return ""
            var lines = []
            if (root.bat.changeRate !== undefined && Math.abs(root.bat.changeRate) > 0.05)
                lines.push("power draw " + Math.abs(root.bat.changeRate).toFixed(1) + " w")
            if (Settings.chargeMode !== "off" && Battery.supported)
                lines.push("charge limit · conservation" + (Battery.held ? ", holding" : ""))
            if (root.bat.healthSupported)
                lines.push("health " + Math.round(root.bat.healthPercentage) + "%")
            return lines.join("\n")
        }
    }
}
