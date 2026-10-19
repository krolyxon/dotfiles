import QtQuick
import QtQuick.Layouts
import Quickshell.Services.UPower

Flickable {
    id: flick
    clip: true
    contentWidth: width
    contentHeight: col.implicitHeight
    boundsBehavior: Flickable.StopAtBounds

    // GiB -> "812G" / "1.8T"
    function size(v) { return v >= 1000 ? (v / 1024).toFixed(1) + "T" : (v >= 100 ? Math.round(v) : v.toFixed(1)) + "G" }

    // pick up drives plugged in since the last poll
    onVisibleChanged: if (visible) SysStats.refreshDisks()

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

        SectionLabel { text: "memory & storage"; Layout.topMargin: 6 }
        StatBar {
            label: "memory"
            frac: SysStats.memTotal > 0 ? SysStats.memUsed / SysStats.memTotal : 0
            valueText: flick.size(SysStats.memUsed) + " / " + flick.size(SysStats.memTotal)
        }
        Repeater {
            model: SysStats.disks
            delegate: StatBar {
                required property var modelData
                label: modelData.label
                frac: modelData.used / modelData.size
                fill: frac > 0.9 ? Theme.err : Theme.accent
                valueText: flick.size(modelData.used) + " / " + flick.size(modelData.size)
            }
        }

        BatteryInfo { Layout.topMargin: 6 }

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

        GpuSwitch { Layout.topMargin: 6 }

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
