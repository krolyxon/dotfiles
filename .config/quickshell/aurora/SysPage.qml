import QtQuick
import QtQuick.Layouts
import Quickshell.Services.UPower

Flickable {
    id: flick
    clip: true
    contentWidth: width
    contentHeight: col.implicitHeight
    boundsBehavior: Flickable.StopAtBounds

    readonly property var bat: UPower.displayDevice
    readonly property bool hasBat: bat !== null && bat.isPresent
    readonly property real batPct: hasBat ? (bat.percentage > 1 ? bat.percentage / 100 : bat.percentage) : 0
    readonly property bool charging: hasBat && bat.state === UPowerDeviceState.Charging

    property string armedGpu: ""
    Timer { id: disarm; interval: 3000; onTriggered: flick.armedGpu = "" }

    function gpuClick(m) {
        if (Gpu.mode === m || Gpu.busy) return
        if (armedGpu !== m) { armedGpu = m; disarm.restart(); return }
        armedGpu = ""
        Gpu.set(m)
    }
    function stateText() {
        if (!hasBat) return ""
        switch (bat.state) {
        case UPowerDeviceState.Charging: return "charging"
        case UPowerDeviceState.Discharging: return "discharging"
        case UPowerDeviceState.FullyCharged: return "full"
        default: return "idle"
        }
    }
    function g(v) { return v.toFixed(1) + "G" }

    ColumnLayout {
        id: col
        width: flick.width
        spacing: 8

        SectionLabel { text: "cpu" }
        RowLayout {
            Layout.fillWidth: true
            spacing: 10
            Text {
                text: Theme.iChip + " " + Math.round(SysStats.cpu * 100) + "%"
                Layout.preferredWidth: 80
                color: Theme.fg
                font.family: Theme.font
                font.pixelSize: Theme.fontSize + 2
                font.bold: true
            }
            Spark { Layout.fillWidth: true; values: SysStats.history }
        }

        SectionLabel { text: "memory & disk"; Layout.topMargin: 6 }
        StatBar {
            label: "memory"
            frac: SysStats.memTotal > 0 ? SysStats.memUsed / SysStats.memTotal : 0
            valueText: flick.g(SysStats.memUsed) + " / " + flick.g(SysStats.memTotal)
        }
        StatBar {
            label: "disk /"
            frac: SysStats.diskTotal > 0 ? SysStats.diskUsed / SysStats.diskTotal : 0
            valueText: Math.round(SysStats.diskUsed) + "G / " + Math.round(SysStats.diskTotal) + "G"
        }

        ColumnLayout {
            visible: flick.hasBat
            Layout.fillWidth: true
            Layout.topMargin: 6
            spacing: 8
            SectionLabel { text: "battery" }
            StatBar {
                label: "charge"
                frac: flick.batPct
                fill: flick.batPct <= 0.15 && !flick.charging ? Theme.err : Theme.accent
                valueText: Math.round(flick.batPct * 100) + "%  " + flick.stateText()
            }
            Text {
                Layout.fillWidth: true
                wrapMode: Text.Wrap
                color: Theme.dim
                font.family: Theme.font
                font.pixelSize: Theme.fontSize - 1
                lineHeight: 1.3
                text: {
                    if (!flick.hasBat) return ""
                    var lines = []
                    var t = flick.charging ? flick.bat.timeToFull : flick.bat.timeToEmpty
                    lines.push((flick.charging ? "time to full   " : "time left      ") + Theme.fmtTime(t))
                    if (flick.bat.changeRate !== undefined)
                        lines.push("power draw     " + Math.abs(flick.bat.changeRate).toFixed(1) + " W")
                    if (flick.bat.healthSupported)
                        lines.push("health         " + Math.round(flick.bat.healthPercentage) + "%")
                    return lines.join("\n")
                }
            }
        }

        ColumnLayout {
            visible: PowerProfiles.hasPerformanceProfile !== undefined
            Layout.fillWidth: true
            Layout.topMargin: 6
            spacing: 8
            SectionLabel { text: "power profile" }
            RowLayout {
                Layout.fillWidth: true
                spacing: 6
                IconBtn {
                    Layout.fillWidth: true
                    icon: Theme.iLeaf
                    label: "saver"
                    active: PowerProfiles.profile === PowerProfile.PowerSaver
                    onClicked: PowerProfiles.profile = PowerProfile.PowerSaver
                }
                IconBtn {
                    Layout.fillWidth: true
                    icon: Theme.iBalance
                    label: "balanced"
                    active: PowerProfiles.profile === PowerProfile.Balanced
                    onClicked: PowerProfiles.profile = PowerProfile.Balanced
                }
                IconBtn {
                    Layout.fillWidth: true
                    visible: PowerProfiles.hasPerformanceProfile
                    icon: Theme.iSpeed
                    label: "perf"
                    active: PowerProfiles.profile === PowerProfile.Performance
                    onClicked: PowerProfiles.profile = PowerProfile.Performance
                }
            }
        }

        ColumnLayout {
            visible: Gpu.mode !== ""
            Layout.fillWidth: true
            Layout.topMargin: 6
            spacing: 8
            SectionLabel { text: "graphics  ·  envycontrol" }
            RowLayout {
                Layout.fillWidth: true
                spacing: 6
                Repeater {
                    model: ["integrated", "hybrid", "nvidia"]
                    delegate: IconBtn {
                        required property string modelData
                        Layout.fillWidth: true
                        icon: Theme.iGpu
                        label: flick.armedGpu === modelData ? "sure?" : modelData
                        active: Gpu.mode === modelData
                        opacity: Gpu.busy ? 0.5 : 1
                        onClicked: flick.gpuClick(modelData)
                    }
                }
            }
            Text {
                visible: Gpu.pending !== "" || Gpu.message !== "" || Gpu.busy
                Layout.fillWidth: true
                wrapMode: Text.Wrap
                color: Gpu.message !== "" ? Theme.err : Theme.accent
                font.family: Theme.font
                font.pixelSize: Theme.fontSize - 2
                text: Gpu.busy ? "switching…" : (Gpu.message !== "" ? Gpu.message : "queued: " + Gpu.pending + "  ·  reboot to apply")
            }
        }

        Text {
            Layout.topMargin: 10
            Layout.alignment: Qt.AlignRight
            text: "up " + Theme.fmtTime(SysStats.uptime)
            color: Theme.dim
            font.family: Theme.font
            font.pixelSize: Theme.fontSize - 2
        }
        Item { Layout.preferredHeight: 6 }
    }
}
