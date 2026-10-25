import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Bluetooth
import Quickshell.Hyprland
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower

PanelWindow {
    id: bar
    required property var modelData
    screen: modelData
    signal togglePanel(string name, var scr)
    signal toggleOverlay(string name, var scr)

    anchors { top: true; left: true; right: true }
    implicitHeight: Theme.barHeight
    color: Theme.barBg
    WlrLayershell.namespace: "aurora-bar"

    SystemClock { id: clock; precision: SystemClock.Minutes }

    // caffeine: one inhibitor is enough, keep it on the first screen's bar
    IdleInhibitor {
        window: bar
        enabled: Toggles.caffeine && bar.modelData === Quickshell.screens[0]
    }

    // ---- state ----
    readonly property var audio: Pipewire.defaultAudioSink ? Pipewire.defaultAudioSink.audio : null
    readonly property var mic: Pipewire.defaultAudioSource ? Pipewire.defaultAudioSource.audio : null
    readonly property var bat: UPower.displayDevice
    readonly property bool hasBat: bat !== null && bat.isPresent
    readonly property real batPct: hasBat ? (bat.percentage > 1 ? bat.percentage / 100 : bat.percentage) : 0
    readonly property bool charging: hasBat && bat.state === UPowerDeviceState.Charging
    readonly property bool plugged: hasBat && bat.state === UPowerDeviceState.FullyCharged
    readonly property bool batLow: hasBat && batPct <= 0.15 && !charging
    readonly property var adapter: Bluetooth.defaultAdapter

    // which Hyprland monitor this bar belongs to, and whether it has focus
    readonly property var hmon: Hyprland.monitorFor(modelData)
    readonly property bool monFocused: hmon !== null && hmon.focused

    function findHeadset() {
        var l = Bluetooth.devices.values
        for (var i = 0; i < l.length; i++) {
            var d = l[i]
            if (!d.connected || !d.batteryAvailable) continue
            var ic = String(d.icon)
            if (ic.indexOf("head") >= 0 || ic.indexOf("audio") >= 0) return d
        }
        return null
    }
    function btConnected() {
        var l = Bluetooth.devices.values
        for (var i = 0; i < l.length; i++) if (l[i].connected) return true
        return false
    }
    readonly property var headset: findHeadset()
    readonly property bool btOn: adapter !== null && adapter.enabled
    readonly property bool btLink: btOn && btConnected()

    Item {
        anchors.fill: parent

        // ---------------- left ----------------
        Row {
            anchors.left: parent.left
            height: parent.height
            spacing: 10
            Workspaces { height: parent.height; monitor: bar.hmon }
            CatLoop { height: parent.height }
        }

        // ---------------- center ----------------
        Text {
            anchors.centerIn: parent
            width: Math.min(implicitWidth, parent.width * 0.32)
            elide: Text.ElideRight
            horizontalAlignment: Text.AlignHCenter
            readonly property string title: ToplevelManager.activeToplevel ? ToplevelManager.activeToplevel.title : ""
            visible: bar.monFocused && title !== ""   // active window is global: show it on the focused monitor only
            text: Theme.iArch + " " + title
            color: Theme.fg
            font.family: Theme.font
            font.pixelSize: Theme.fontSize
            font.bold: true
        }

        // ---------------- right ----------------
        Row {
            anchors.right: parent.right
            height: parent.height
            spacing: 10

            Tray { show: bar.monFocused }

            BarPill {   // click to stop recording / cancel the area selection
                visible: Rec.busy
                icon: Theme.iStop
                text: Rec.running ? "rec " + Theme.fmtClock(Rec.elapsed) : "select area"
                tint: Theme.err
                underline: Theme.err
                onActivated: Rec.stop()
            }

            // privacy: global, so only on the focused monitor's bar. Click the mic one to mute the mic.
            BarPill {
                visible: bar.monFocused && Privacy.mic
                icon: bar.mic && bar.mic.muted ? Theme.iMicOff : Theme.iMic
                text: Privacy.micApps.join(", ")
                tint: bar.mic && bar.mic.muted ? Theme.dim : Theme.err
                underline: Theme.err
                onActivated: if (bar.mic) bar.mic.muted = !bar.mic.muted
            }
            BarPill {
                visible: bar.monFocused && Privacy.cam
                icon: Theme.iWebcam
                text: Privacy.camApps.join(", ")
                tint: Theme.err
                underline: Theme.err
            }
            BarPill {
                visible: bar.monFocused && Privacy.screen
                icon: Theme.iCast
                text: Privacy.shareApps.join(", ")
                tint: Theme.err
                underline: Theme.err
            }

            BarPill {   // left click: list in the sys tab, right click: upgrade in foot
                visible: bar.monFocused && Settings.updatesPill && Updates.count > 0
                icon: Theme.iUpdate
                text: String(Updates.count)
                tint: Updates.upgrading ? Theme.dim : Theme.fg
                onActivated: button => {
                    if (button === Qt.RightButton) Updates.upgrade()
                    else bar.togglePanel("sys", bar.modelData)
                }
            }

            BarPill {
                visible: Toggles.caffeine || Toggles.airplane
                icon: (Toggles.caffeine ? Theme.iCoffee : "") + (Toggles.caffeine && Toggles.airplane ? " " : "")
                      + (Toggles.airplane ? Theme.iPlane : "")
                onActivated: bar.togglePanel("home", bar.modelData)
            }

            BarPill {
                visible: bar.headset !== null
                icon: Theme.iHeadphones
                text: bar.headset ? Math.round(bar.headset.battery * 100) + "%" : ""
                onActivated: bar.togglePanel("bt", bar.modelData)
            }

            BarPill {
                visible: bar.audio !== null
                icon: Theme.volIcon(bar.audio ? bar.audio.volume : 0, bar.audio ? bar.audio.muted : true)
                text: (bar.audio ? Math.round(bar.audio.volume * 100) : 0) + "%"
                      + (bar.mic && bar.mic.muted ? "  " + Theme.iMicOff : "")
                onActivated: button => {
                    if (button === Qt.RightButton && bar.audio) bar.audio.muted = !bar.audio.muted
                    else if (button === Qt.MiddleButton && bar.mic) bar.mic.muted = !bar.mic.muted
                    else bar.togglePanel("audio", bar.modelData)
                }
                onScrolled: dir => {
                    if (bar.audio) bar.audio.volume = Math.max(0, Math.min(1, bar.audio.volume + dir * 0.02))
                }
            }

            BarPill {
                icon: Net.wired && !(Net.wifiEnabled && Net.connected !== "") ? Net.wiredIcon
                      : (Net.wifiEnabled ? Theme.wifiIcon(Net.connected !== "" ? Net.activeSignal : 0) : Theme.iWifiOff)
                tint: Net.portal ? Theme.err : ((Net.wired || (Net.wifiEnabled && Net.connected !== "")) ? Theme.fg : Theme.dim)
                onActivated: bar.togglePanel("net", bar.modelData)
            }

            BarPill {
                visible: bar.adapter !== null
                icon: !bar.btOn ? Theme.iBtOff : (bar.btLink ? Theme.iBtConn : Theme.iBt)
                tint: bar.btLink ? Theme.fg : Theme.dim
                onActivated: bar.togglePanel("bt", bar.modelData)
            }

            BarPill {
                visible: bar.hasBat
                icon: Theme.batIcon(bar.batPct, bar.charging, bar.plugged)
                text: Math.round(bar.batPct * 100) + "%"
                tint: bar.batLow ? Theme.err : Theme.fg
                underline: bar.batLow ? Theme.err : Theme.accent
                onActivated: bar.togglePanel("sys", bar.modelData)
            }

            BarPill {
                icon: Notifs.dnd ? Theme.iBellOff : Theme.iBell
                text: Notifs.count > 0 ? String(Notifs.count) : ""
                tint: Notifs.dnd ? Theme.dim : Theme.fg
                onActivated: button => {
                    if (button === Qt.RightButton) Notifs.dnd = !Notifs.dnd
                    else bar.togglePanel("notif", bar.modelData)
                }
            }

            BarPill {
                icon: Theme.iCal
                text: Qt.formatDateTime(clock.date, "dd MMM yyyy")
                onActivated: bar.toggleOverlay("cal", bar.modelData)
            }
            BarPill {
                icon: Theme.iClock
                text: Qt.formatDateTime(clock.date, "HH:mm")
                onActivated: bar.toggleOverlay("cal", bar.modelData)
            }
        }
    }
}
