import QtQuick
import QtQuick.Layouts
import Quickshell.Services.UPower

// Control panel > sys: cpu (Doto value + dot-matrix history), memory and disks, removable drives,
// battery, power profile, graphics mode, pending updates, uptime.
Flickable {
    id: flick
    clip: true
    contentWidth: width
    contentHeight: col.implicitHeight
    implicitHeight: col.implicitHeight
    boundsBehavior: Flickable.StopAtBounds

    // GiB -> "812G" / "1.8T"
    function size(v) { return v >= 1000 ? (v / 1024).toFixed(1) + "T" : (v >= 100 ? Math.round(v) : v.toFixed(1)) + "G" }

    // pick up drives plugged in since the last poll
    onVisibleChanged: if (visible) { SysStats.refreshDisks(); Updates.check(false) }

    ColumnLayout {
        id: col
        width: flick.width
        spacing: 10

        SectionLabel { text: "cpu · 40 s" }
        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: 6
            spacing: 18
            Num {
                Layout.preferredWidth: 96
                text: Math.round(SysStats.cpu * 100) + "%"
                font.pixelSize: 44
            }
            Spark {
                Layout.fillWidth: true
                Layout.preferredWidth: 100
                Layout.preferredHeight: 44
                values: SysStats.history
            }
        }

        SectionLabel { text: "memory · storage"; Layout.topMargin: 8 }
        StatBar {
            label: "memory"
            frac: SysStats.memTotal > 0 ? SysStats.memUsed / SysStats.memTotal : 0
            valueText: flick.size(SysStats.memUsed) + " / " + flick.size(SysStats.memTotal)
            Layout.leftMargin: 6
            Layout.rightMargin: 6
        }
        Repeater {
            model: SysStats.disks
            delegate: StatBar {
                required property var modelData
                Layout.leftMargin: 6
                Layout.rightMargin: 6
                label: modelData.label
                frac: modelData.used / modelData.size
                fill: frac > 0.9 ? Theme.err : Theme.fill
                valueText: flick.size(modelData.used) + " / " + flick.size(modelData.size)
            }
        }

        // removable drives + phones (Devices): mount / open / unmount, power-off once the disk is idle
        SectionLabel { text: "removable"; Layout.topMargin: 8; visible: Devices.drives.length + Devices.phones.length > 0 }
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
                                : modelData.size + " · " + modelData.fstype + " · " + (mounted ? modelData.mount : (modelData.locked ? "locked" : "not mounted"))
                current: mounted
                onClicked: if (mounted) Devices.open(modelData.key); else Devices.mount(modelData.key, true)
                IconBtn {
                    icon: Theme.iFolderOpen
                    implicitHeight: 32
                    onClicked: if (dr.mounted) Devices.open(dr.modelData.key); else Devices.mount(dr.modelData.key, true)
                }
                IconBtn {
                    icon: Theme.iEject
                    implicitHeight: 32
                    visible: dr.mounted || (!dr.phone && dr.modelData.luksParent !== "")
                    onClicked: Devices.eject(dr.modelData.key)
                }
                IconBtn {
                    icon: Theme.iPower
                    implicitHeight: 32
                    visible: dr.firstOfDisk && !Devices.diskBusy(dr.modelData.disk)
                    onClicked: Devices.powerOff(dr.modelData.disk)
                }
            }
        }

        BatteryInfo { Layout.topMargin: 8 }

        SectionLabel { text: "power profile"; Layout.topMargin: 8; visible: Battery.hasProfiles }
        Segmented {
            Layout.fillWidth: true
            visible: Battery.hasProfiles
            options: {
                var o = [{ value: "saver", label: "saver", ticks: 1 }, { value: "balanced", label: "bal", ticks: 2 }]
                if (Battery.hasPerf) o.push({ value: "performance", label: "perf", ticks: 4 })
                if (Battery.hasBat) o.push({ value: "auto", label: "auto" })
                return o
            }
            value: Battery.profile
            onPicked: v => Battery.setProfile(v)
        }

        GpuSwitch { Layout.topMargin: 8 }

        // pending pacman + AUR updates (Updates)
        SectionLabel {
            visible: Updates.available
            Layout.topMargin: 8
            text: "updates"
            count: Updates.count > 0 ? String(Updates.count) : ""
        }
        RowLayout {
            visible: Updates.available
            Layout.fillWidth: true
            Layout.leftMargin: 6
            spacing: 8
            Lb {
                Layout.fillWidth: true
                elide: Text.ElideRight
                px: 10
                text: Updates.checking ? "checking…"
                      : Updates.error !== "" ? Updates.error
                      : (Updates.count === 0 ? "up to date" : Updates.repo + " repo · " + Updates.aur + " aur")
                        + (Updates.lastCheck.getTime() > 0 ? " · " + Qt.formatDateTime(Updates.lastCheck, "HH:mm") : "")
                color: Updates.error !== "" ? Theme.err : Theme.fg
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
        Lb {
            visible: Updates.available && Updates.list.length > 6
            Layout.leftMargin: 6
            px: 10
            text: "+ " + (Updates.list.length - 6) + " more"
        }

        Lb {
            Layout.topMargin: 10
            Layout.rightMargin: 6
            Layout.alignment: Qt.AlignRight
            px: 10
            text: "up " + Theme.fmtTime(SysStats.uptime)
        }
        Item { Layout.preferredHeight: 4 }
    }
}
