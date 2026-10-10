import QtQuick
import QtQuick.Layouts
import Quickshell.Bluetooth

ColumnLayout {
    id: page
    property bool active: false
    spacing: 8

    readonly property var adapter: Bluetooth.defaultAdapter

    onActiveChanged: {
        if (adapter) adapter.discovering = active && adapter.enabled
    }

    function paired(d) { return d.bonded === true || d.paired === true }

    function looksLikeAddress(d) {
        return String(d.name).replace(/-/g, ":").toUpperCase() === String(d.address).toUpperCase()
    }

    function devIcon(d) {
        var i = String(d.icon || "")
        if (i.indexOf("head") >= 0) return Theme.iHeadphones
        if (i.indexOf("mouse") >= 0) return Theme.iMouse
        if (i.indexOf("keyboard") >= 0) return Theme.iKeyboard
        if (i.indexOf("phone") >= 0) return Theme.iPhone
        if (i.indexOf("gaming") >= 0 || i.indexOf("joystick") >= 0) return Theme.iGamepad
        if (i.indexOf("speaker") >= 0) return Theme.iSpeaker
        return d.connected ? Theme.iBtConn : Theme.iBt
    }

    function list() {
        var src = Bluetooth.devices.values, out = []
        var scanning = adapter ? adapter.discovering : false
        for (var i = 0; i < src.length; i++) {
            var d = src[i]
            if (d.connected || paired(d)) out.push(d)
            else if (scanning && !looksLikeAddress(d)) out.push(d)
        }
        out.sort(function (a, b) {
            if (a.connected !== b.connected) return a.connected ? -1 : 1
            var pa = paired(a), pb = paired(b)
            if (pa !== pb) return pa ? -1 : 1
            return String(a.name).localeCompare(String(b.name))
        })
        return out
    }
    readonly property var devices: list()

    RowLayout {
        Layout.fillWidth: true
        spacing: 6
        Text {
            Layout.fillWidth: true
            elide: Text.ElideRight
            text: !page.adapter ? "no bluetooth adapter"
                  : (!page.adapter.enabled ? "bluetooth is off"
                  : (page.adapter.discovering ? "scanning…" : (page.adapter.name || "adapter ready")))
            color: page.adapter && page.adapter.enabled ? Theme.accent : Theme.dim
            font.family: Theme.font
            font.pixelSize: Theme.fontSize
        }
        IconBtn {
            visible: page.adapter !== null
            icon: Theme.iSearch
            active: page.adapter ? page.adapter.discovering : false
            onClicked: if (page.adapter && page.adapter.enabled) page.adapter.discovering = !page.adapter.discovering
        }
        IconBtn {
            visible: page.adapter !== null
            icon: page.adapter && page.adapter.enabled ? Theme.iBt : Theme.iBtOff
            active: page.adapter ? page.adapter.enabled : false
            onClicked: {
                if (!page.adapter) return
                page.adapter.enabled = !page.adapter.enabled
                if (page.adapter.enabled && page.active) page.adapter.discovering = true
            }
        }
    }

    SectionLabel { text: "devices" }

    Flickable {
        id: flick
        Layout.fillWidth: true
        Layout.fillHeight: true
        clip: true
        contentWidth: width
        contentHeight: col.implicitHeight
        boundsBehavior: Flickable.StopAtBounds

        ColumnLayout {
            id: col
            width: flick.width
            spacing: 2

            Repeater {
                model: page.adapter && page.adapter.enabled ? page.devices : []
                delegate: ListRow {
                    id: row
                    required property var modelData
                    readonly property var dev: modelData
                    property bool pendingConnect: false

                    function afterPair() {
                        if (pendingConnect && page.paired(dev)) { pendingConnect = false; dev.connect() }
                    }

                    icon: page.devIcon(dev)
                    title: dev.name || dev.address
                    current: dev.connected
                    subtitle: {
                        if (dev.state === BluetoothDeviceState.Connecting) return "connecting…"
                        if (dev.pairing) return "pairing…"
                        if (dev.connected)
                            return "connected" + (dev.batteryAvailable ? "  ·  " + Math.round(dev.battery * 100) + "%" : "")
                        return page.paired(dev) ? "paired" : "available"
                    }
                    onClicked: {
                        if (dev.connected) dev.disconnect()
                        else if (page.paired(dev)) dev.connect()
                        else { pendingConnect = true; dev.trusted = true; dev.pair() }
                    }

                    // property name differs between Quickshell versions
                    Connections {
                        target: row.dev
                        ignoreUnknownSignals: true
                        function onBondedChanged() { row.afterPair() }
                        function onPairedChanged() { row.afterPair() }
                    }
                    IconBtn {
                        visible: page.paired(row.dev)
                        icon: Theme.iTrash
                        height: 26
                        onClicked: row.dev.forget()
                    }
                }
            }
        }
    }
}
