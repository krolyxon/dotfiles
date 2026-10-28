import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Bluetooth
import Quickshell.Hyprland
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower

// The bar: a strip docked at the top of every monitor.
// Left: the mark (a dotted ring: click = runner; its centre turns the live colour while something records or listens,
// the ring lights up in a wave on a new notification), this monitor's workspaces as dots, the cat.
// Centre: time · day (click = calendar). Right: tray, recording, privacy, caffeine/airplane, headset, volume,
// net + bt, battery. Clicks open the same panel tabs as always.
// After glyph-rice (github.com/Nebelung-cloud/glyph-rice, GPL-3.0), bar/Bar.qml.
PanelWindow {
    id: bar
    required property var modelData
    screen: modelData
    signal togglePanel(string name, var scr)
    signal toggleOverlay(string name, var scr)

    anchors { top: true; left: true; right: true }
    implicitHeight: Theme.barHeight
    color: "transparent"
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
    readonly property bool batLow: hasBat && batPct <= Settings.batLow / 100 && !charging
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
    // something records or listens: the mark's centre goes live
    readonly property bool live: Rec.busy || Privacy.mic || Privacy.cam || Privacy.screen

    // a new toast: the mark's ring lights up for 3s (error colour if critical)
    property bool flash: false
    property bool flashCrit: false
    Timer { id: flashT; interval: 3000; onTriggered: bar.flash = false }
    Connections {
        target: Notifs
        function onArrived(n, critical) { bar.flashCrit = critical; bar.flash = true; flashT.restart() }
    }

    Rectangle {
        id: pill
        anchors.fill: parent
        color: Theme.fade(Theme.s1, Theme.barAlpha)
        Rectangle {   // hairline along the bottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: 1
            color: Theme.s2
        }

        // ---------------- left ----------------
        Row {
            anchors.left: parent.left
            anchors.leftMargin: Math.round(Theme.barSize * 0.25)
            height: parent.height
            spacing: 14

            Item {
                id: mark
                readonly property real size: Math.round(Theme.barSize * 0.55)
                width: size
                height: size
                anchors.verticalCenter: parent.verticalCenter
                Ring {
                    anchors.fill: parent
                    anchors.margins: 1.5
                    n: 16
                    dot: 2.6
                    on: bar.flash ? (bar.flashCrit ? Theme.err : Theme.fill) : Theme.fg
                    off: Theme.s3
                }
                Rectangle {
                    anchors.centerIn: parent
                    width: Math.round(mark.size * 0.32)
                    height: width
                    radius: width / 2
                    color: bar.live ? Theme.live : Theme.fg
                }
                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -5
                    cursorShape: Qt.PointingHandCursor
                    onClicked: bar.toggleOverlay("runner", bar.modelData)
                }
            }
            Workspaces { height: parent.height; monitor: bar.hmon }
            CatLoop { height: parent.height }
        }

        // ---------------- center: time · day, one line (click = calendar) ----------------
        BarPill {
            anchors.centerIn: parent
            height: parent.height
            text: Theme.hh(clock.date) + ":" + Qt.formatDateTime(clock.date, "mm") + "  ·  " + Qt.locale("en_US").toString(clock.date, "ddd d")
            onActivated: bar.toggleOverlay("cal", bar.modelData)
        }

        // ---------------- right ----------------
        Row {
            anchors.right: parent.right
            anchors.rightMargin: 6
            height: parent.height
            spacing: 0

            Tray { show: bar.monFocused }

            BarPill {   // click to stop recording / cancel the area selection
                visible: Rec.busy
                icon: Theme.iStop
                text: Rec.running ? "rec " + Theme.fmtClock(Rec.elapsed) : "select area"
                tint: Theme.live
                onActivated: Rec.stop()
            }

            // privacy: global, so only on the focused monitor's bar. Click the mic one to mute the mic.
            BarPill {
                visible: bar.monFocused && Privacy.mic
                icon: bar.mic && bar.mic.muted ? Theme.iMicOff : Theme.iMic
                text: Privacy.micApps.join(", ")
                tint: bar.mic && bar.mic.muted ? Theme.grey : Theme.live
                onActivated: if (bar.mic) bar.mic.muted = !bar.mic.muted
            }
            BarPill {
                visible: bar.monFocused && Privacy.cam
                icon: Theme.iWebcam
                text: Privacy.camApps.join(", ")
                tint: Theme.live
            }
            BarPill {
                visible: bar.monFocused && Privacy.screen
                icon: Theme.iCast
                text: Privacy.shareApps.join(", ")
                tint: Theme.live
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
                tint: bar.audio && bar.audio.muted ? Theme.grey : Theme.fg
                icon2: bar.mic && bar.mic.muted ? Theme.iMicOff : ""
                tint2: Theme.grey
                onActivated: button => {
                    if (button === Qt.RightButton && bar.audio) bar.audio.muted = !bar.audio.muted
                    else if (button === Qt.MiddleButton && bar.mic) bar.mic.muted = !bar.mic.muted
                    else bar.togglePanel("audio", bar.modelData)
                }
                onActivated2: button => { if (bar.mic) bar.mic.muted = !bar.mic.muted }
                onScrolled: dir => {
                    if (bar.audio) bar.audio.volume = Math.max(0, Math.min(1, bar.audio.volume + dir * 0.02))
                }
            }

            // net + bt share one block: click the left icon for the net tab, the right one for bt
            BarPill {
                icon: Net.wired && !(Net.wifiEnabled && Net.connected !== "") ? Net.wiredIcon
                      : (Net.wifiEnabled ? Theme.wifiIcon(Net.connected !== "" ? Net.activeSignal : 0) : Theme.iWifiOff)
                tint: Net.portal ? Theme.live : ((Net.wired || (Net.wifiEnabled && Net.connected !== "")) ? Theme.fg : Theme.grey)
                icon2: bar.adapter === null ? "" : (!bar.btOn ? Theme.iBtOff : (bar.btLink ? Theme.iBtConn : Theme.iBt))
                tint2: bar.btLink ? Theme.fg : Theme.grey
                onActivated: bar.togglePanel("net", bar.modelData)
                onActivated2: bar.togglePanel("bt", bar.modelData)
            }

            // battery: a capsule that fills up, the error colour when low, a bolt + breathing fill while charging
            BarPill {
                id: batt
                visible: bar.hasBat
                icon: bar.charging ? Theme.iBolt : ""
                onActivated: bar.togglePanel("sys", bar.modelData)
                // breathing at 20 steps a second: an Animation would redraw the bar on every vsync while charging
                property real phase: 0
                readonly property real pulse: bar.charging ? 0.675 + 0.325 * Math.cos(phase * Math.PI / 1.1) : 1
                Timer {
                    running: bar.charging && bar.visible
                    interval: 50
                    repeat: true
                    onTriggered: batt.phase = (batt.phase + 0.05) % 2.2
                    onRunningChanged: batt.phase = 0
                }
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 26
                    height: 13
                    radius: height / 2
                    color: "transparent"
                    border.width: 1.5
                    border.color: bar.batLow ? Theme.err : Theme.grey
                    Rectangle {
                        x: 3
                        anchors.verticalCenter: parent.verticalCenter
                        width: Math.max(3, (parent.width - 6) * bar.batPct)
                        height: parent.height - 6
                        radius: height / 2
                        color: bar.batLow ? Theme.err : Theme.fill
                        opacity: batt.pulse
                    }
                }
                Lb {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Math.round(bar.batPct * 100)
                    px: 11
                    color: bar.batLow ? Theme.err : Theme.fg
                }
            }
        }
    }
}
