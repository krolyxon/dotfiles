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
    onVisibleChanged: if (visible) { SysStats.refreshDisks(); Updates.check(false) }

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

        // removable drives + phones (Devices): mount / open / unmount, power-off once the disk is idle
        SectionLabel { text: "removable"; Layout.topMargin: 6; visible: Devices.drives.length + Devices.phones.length > 0 }
        Repeater {
            model: Devices.drives.concat(Devices.phones)
            delegate: ListRow {
                id: dr
                required property var modelData
                required property int index
                readonly property bool phone: modelData.uri !== undefined
                readonly property bool mounted: phone ? modelData.mounted : modelData.mount !== ""
                // first row of its disk carries the power-off button
                readonly property bool firstOfDisk: !phone && (index === 0 || Devices.drives[index - 1].disk !== modelData.disk)
                icon: phone ? Theme.iPhone : (modelData.locked ? Theme.iLock : Theme.iUsb)
                title: phone ? modelData.name : Devices.title(modelData)
                subtitle: phone ? (mounted ? modelData.path : "not mounted")
                                : modelData.size + "  " + modelData.fstype + "  " + (mounted ? modelData.mount : (modelData.locked ? "locked" : "not mounted"))
                current: mounted
                onClicked: if (mounted) Devices.open(modelData.key); else Devices.mount(modelData.key, true)
                IconBtn {
                    icon: Theme.iFolderOpen
                    onClicked: if (dr.mounted) Devices.open(dr.modelData.key); else Devices.mount(dr.modelData.key, true)
                }
                IconBtn {
                    icon: Theme.iEject
                    visible: dr.mounted || (!dr.phone && dr.modelData.luksParent !== "")
                    onClicked: Devices.eject(dr.modelData.key)
                }
                IconBtn {
                    icon: Theme.iPower
                    visible: dr.firstOfDisk && !Devices.diskBusy(dr.modelData.disk)
                    onClicked: Devices.powerOff(dr.modelData.disk)
                }
            }
        }

        // pending pacman + AUR updates (Updates)
        SectionLabel { text: "updates"; Layout.topMargin: 6; visible: Updates.available }
        RowLayout {
            visible: Updates.available
            Layout.fillWidth: true
            spacing: 6
            Text {
                Layout.fillWidth: true
                text: Updates.checking ? "checking..."
                      : Updates.error !== "" ? Updates.error
                      : (Updates.count === 0 ? "up to date" : Updates.repo + " repo, " + Updates.aur + " aur")
                        + (Updates.lastCheck.getTime() > 0 ? "  ·  " + Qt.formatDateTime(Updates.lastCheck, "HH:mm") : "")
                color: Updates.error !== "" ? Theme.err : Theme.fg
                font.family: Theme.font
                font.pixelSize: Theme.fontSize
                elide: Text.ElideRight
            }
            IconBtn { icon: Theme.iRefresh; label: "check"; onClicked: Updates.check(true) }
            IconBtn {
                visible: Updates.count > 0
                icon: Theme.iUpdate
                label: Updates.upgrading ? "running" : "upgrade"
                active: Updates.upgrading
                onClicked: Updates.upgrade()
            }
        }
        Repeater {
            model: Updates.available ? Updates.list.slice(0, 6) : []
            delegate: ListRow {
                required property var modelData
                icon: Theme.iUpdate
                title: modelData.name
                subtitle: modelData.from + " → " + modelData.to
                trailing: modelData.aur ? "aur" : ""
            }
        }
        Text {
            visible: Updates.available && Updates.list.length > 6
            text: "+ " + (Updates.list.length - 6) + " more"
            color: Theme.dim
            font.family: Theme.font
            font.pixelSize: Theme.fontSize - 2
        }

        BatteryInfo { Layout.topMargin: 6 }

        ColumnLayout {
            visible: Battery.hasProfiles
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
                    active: Battery.profile === "saver"
                    onClicked: Battery.setProfile("saver")
                }
                IconBtn {
                    Layout.fillWidth: true
                    icon: Theme.iBalance
                    label: "balanced"
                    active: Battery.profile === "balanced"
                    onClicked: Battery.setProfile("balanced")
                }
                IconBtn {
                    Layout.fillWidth: true
                    visible: PowerProfiles.hasPerformanceProfile
                    icon: Theme.iSpeed
                    label: "perf"
                    active: Battery.profile === "performance"
                    onClicked: Battery.setProfile("performance")
                }
                IconBtn {
                    Layout.fillWidth: true
                    visible: Battery.hasBat
                    icon: Theme.iAuto
                    label: "auto"
                    active: Battery.profile === "auto"
                    onClicked: Battery.setProfile("auto")
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
