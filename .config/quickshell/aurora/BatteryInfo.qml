import QtQuick
import QtQuick.Layouts
import Quickshell.Services.UPower

// battery block: charge bar, time left / to full, power draw, health (SysPage, settings app > Power)
ColumnLayout {
    id: root
    readonly property var bat: UPower.displayDevice
    readonly property bool hasBat: bat !== null && bat.isPresent
    readonly property real batPct: hasBat ? (bat.percentage > 1 ? bat.percentage / 100 : bat.percentage) : 0
    readonly property bool charging: hasBat && bat.state === UPowerDeviceState.Charging
    function stateText() {
        if (!hasBat) return ""
        switch (bat.state) {
        case UPowerDeviceState.Charging: return "charging"
        case UPowerDeviceState.Discharging: return "discharging"
        case UPowerDeviceState.FullyCharged: return "full"
        default: return "idle"
        }
    }
    visible: hasBat
    Layout.fillWidth: true
    spacing: 8
    SectionLabel { text: "battery" }
    StatBar {
        label: "charge"
        frac: root.batPct
        fill: root.batPct <= 0.15 && !root.charging ? Theme.err : Theme.accent
        valueText: Math.round(root.batPct * 100) + "%  " + root.stateText()
    }
    Text {
        Layout.fillWidth: true
        wrapMode: Text.Wrap
        color: Theme.dim
        font.family: Theme.font
        font.pixelSize: Theme.fontSize - 1
        lineHeight: 1.3
        text: {
            if (!root.hasBat) return ""
            var lines = []
            var t = root.charging ? root.bat.timeToFull : root.bat.timeToEmpty
            lines.push((root.charging ? "time to full   " : "time left      ") + Theme.fmtTime(t))
            if (root.bat.changeRate !== undefined)
                lines.push("power draw     " + Math.abs(root.bat.changeRate).toFixed(1) + " W")
            if (Settings.chargeMode !== "off" && Battery.supported)
                lines.push("charge limit   conservation" + (Battery.held ? ", holding" : ""))
            if (root.bat.healthSupported)
                lines.push("health         " + Math.round(root.bat.healthPercentage) + "%")
            return lines.join("\n")
        }
    }
}
