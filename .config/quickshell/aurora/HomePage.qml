import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Services.Pipewire

// Control panel > home: Wi-Fi / Bluetooth pills (chevron = their tab), round toggles, desktop actions, capture,
// volume + brightness, power profile, the player, the latest notifications. Session actions: the header's power button.
// After glyph-rice's quick settings (github.com/Nebelung-cloud/glyph-rice, GPL-3.0), quick/Quick.qml.
Flickable {
    id: page
    signal closeRequested()
    signal overlayRequested(string name)
    signal tabRequested(string name)

    clip: true
    contentWidth: width
    contentHeight: col.implicitHeight
    implicitHeight: col.implicitHeight
    boundsBehavior: Flickable.StopAtBounds


    readonly property var sink: Pipewire.defaultAudioSink ? Pipewire.defaultAudioSink.audio : null
    readonly property var source: Pipewire.defaultAudioSource ? Pipewire.defaultAudioSource.audio : null
    readonly property var adapter: Bluetooth.defaultAdapter
    function btDevice() {
        var l = Bluetooth.devices.values
        for (var i = 0; i < l.length; i++) if (l[i].connected) return l[i]
        return null
    }
    readonly property var btDev: btDevice()

    Timer {
        interval: 3000
        running: page.visible
        repeat: true
        triggeredOnStart: true
        onTriggered: Bright.refresh()
    }

    ColumnLayout {
        id: col
        width: page.width
        spacing: 16

        // ---- Wi-Fi / Bluetooth ----
        RowLayout {
            Layout.fillWidth: true
            spacing: 12
            TogglePill {
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                on: Net.wifiEnabled
                icon: Net.wifiEnabled ? Theme.wifiIcon(Net.connected !== "" ? Net.activeSignal : 0) : Theme.iWifiOff
                name: "Wi-Fi"
                alert: Net.portal
                sub: {
                    if (Net.portal) return "sign in · " + Net.portalNet
                    if (!Net.wifiEnabled) return Net.wired ? "off · wired" : "off"
                    if (Net.connected !== "") return Net.connected
                    return Net.wired ? "wired · " + Net.wiredDevs[0].name : "not connected"
                }
                onClicked: Net.setWifi(!Net.wifiEnabled)
                onMenu: page.tabRequested("net")
            }
            TogglePill {
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                on: page.adapter !== null && page.adapter.enabled
                icon: !on ? Theme.iBtOff : (page.btDev ? Theme.iBtConn : Theme.iBt)
                name: "Bluetooth"
                sub: page.adapter === null ? "no adapter" : (!page.adapter.enabled ? "off"
                     : (page.btDev ? (page.btDev.name || page.btDev.address) : "on"))
                onClicked: if (page.adapter) page.adapter.enabled = !page.adapter.enabled
                onMenu: page.tabRequested("bt")
            }
        }

        // ---- toggles ----
        Grid {
            id: tiles
            Layout.fillWidth: true
            Layout.preferredWidth: 1
            columns: 4
            rowSpacing: 14
            readonly property real cw: width / 4
            Tile {
                width: tiles.cw
                icon: Theme.iBellOff
                name: "dnd"
                on: Notifs.dnd
                onClicked: Notifs.dnd = !Notifs.dnd
            }
            Tile {
                width: tiles.cw
                icon: page.source && !page.source.muted ? Theme.iMic : Theme.iMicOff
                name: "mic"
                on: page.source !== null && !page.source.muted
                onClicked: if (page.source) page.source.muted = !page.source.muted
            }
            Tile {
                width: tiles.cw
                icon: Theme.iCoffee
                name: "caffeine"
                on: Toggles.caffeine
                onClicked: Toggles.caffeine = !Toggles.caffeine
            }
            Tile {
                width: tiles.cw
                icon: Theme.iPlane
                name: "airplane"
                on: Toggles.airplane
                onClicked: Toggles.setAirplane(!Toggles.airplane)
            }
            Tile {
                width: tiles.cw
                visible: Toggles.hasNightLight
                icon: Theme.iNight
                name: "night"
                on: Toggles.nightLight
                onClicked: Toggles.setNightLight(!Toggles.nightLight)
            }
            Tile {   // click: record the focused monitor, right click: a region; while recording: stop
                width: tiles.cw
                visible: Rec.available
                icon: Rec.busy ? Theme.iStop : Theme.iRec
                name: Rec.running ? Theme.fmtClock(Rec.elapsed) : (Rec.selecting ? "select" : "rec")
                live: Rec.busy
                onClicked: { if (!Rec.busy) page.closeRequested(); Rec.toggle("screen") }
                onMenu: { if (!Rec.busy) { page.closeRequested(); Rec.toggle("region") } }
            }
            Tile {
                width: tiles.cw
                visible: Toggles.hasPicker
                icon: Theme.iPicker
                name: "colour"
                onClicked: { page.closeRequested(); Toggles.pickColour() }
            }
            Tile {   // click: the screenshot viewfinder (after the panel is gone), right click: ocr
                width: tiles.cw
                icon: Theme.iShot
                name: "shot"
                onClicked: { page.closeRequested(); Shot.open("region", Theme.t + 60) }
                onMenu: { page.closeRequested(); Shot.ocr(Theme.t + 60) }
            }
        }

        // ---- desktop ----
        RowLayout {
            Layout.fillWidth: true
            spacing: 0
            Tile { Layout.fillWidth: true; Layout.preferredWidth: 1; size: 44; icon: Theme.iImage; name: "wallpaper"; onClicked: page.overlayRequested("wall") }
            Tile { Layout.fillWidth: true; Layout.preferredWidth: 1; size: 44; icon: Theme.iShuffle; name: "random"; onClicked: Wall.random() }
            Tile { Layout.fillWidth: true; Layout.preferredWidth: 1; size: 44; icon: Theme.iDashboard; name: "overview"; onClicked: page.overlayRequested("overview") }
            Tile { Layout.fillWidth: true; Layout.preferredWidth: 1; size: 44; visible: Clip.available; icon: Theme.iClipboard; name: "clipboard"; onClicked: page.overlayRequested("clip") }
        }

        // ---- levels (mic level is in the SOUND tab) ----
        SliderRow {
            Layout.fillWidth: true
            icon: Theme.volIcon(page.sink ? page.sink.volume : 0, page.sink ? page.sink.muted : true)
            value: page.sink ? page.sink.volume : 0
            muted: page.sink ? page.sink.muted : false
            onMoved: v => { if (page.sink) page.sink.volume = v }
            onIconClicked: if (page.sink) page.sink.muted = !page.sink.muted
        }
        SliderRow {
            Layout.fillWidth: true
            visible: Bright.available
            icon: Theme.iBright
            value: Bright.percent / 100
            valueText: Bright.percent + "%"
            onMoved: v => Bright.setPercent(Math.max(0.01, v) * 100)
        }

        // ---- power profile (only with power-profiles-daemon) ----
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

        MediaCard { Layout.fillWidth: true }

        // ---- the latest notifications (all of them: NOTIF tab) ----
        SectionLabel {
            visible: Notifs.count > 0
            text: "notifications"
            count: String(Notifs.count)
            action: "clear all"
            onActionClicked: Notifs.clearAll()
        }
        Repeater {
            model: { Notifs.count; return Notifs.history().slice(0, 2) }
            delegate: NotifCard {
                required property var modelData
                n: modelData
            }
        }
        Chip {
            visible: Notifs.count > 2
            Layout.alignment: Qt.AlignHCenter
            text: "+ " + (Notifs.count - 2) + " more"
            onClicked: page.tabRequested("notifs")
        }
    }
}
