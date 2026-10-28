import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Bluetooth
import Quickshell.Services.UPower

// The home screen of one monitor (Bottom layer: above the wallpaper, under windows, never takes input):
// a 300px Doto clock with a blinking colon, the date, a greeting, a meta line, and a bento of widgets
// (Settings.homeWidgets, 3 x 3 cells of 220px; wide ones span cells, what doesn't fit is left out).
// Laid out on a 1920 x 1080 canvas scaled to the screen. Clocks blink and the cover spins only while the workspace is empty.
// After glyph-rice (github.com/Nebelung-cloud/glyph-rice, GPL-3.0), home/Home.qml.
PanelWindow {
    id: win
    required property var modelData
    screen: modelData

    visible: Settings.desktopClock
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    mask: Region {}
    WlrLayershell.layer: WlrLayer.Bottom
    WlrLayershell.namespace: "aurora-desktop"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    readonly property var hmon: Hyprland.monitorFor(modelData)
    readonly property bool home: hmon && hmon.activeWorkspace ? hmon.activeWorkspace.toplevels.values.length === 0 : true

    SystemClock { id: clock; precision: SystemClock.Minutes }
    readonly property var en: Qt.locale("en_US")

    // blinking colon: two frames a second, not an animation on every vsync
    property bool dim: false
    Timer { running: win.home && Settings.blink && win.visible; interval: 500; repeat: true; onTriggered: win.dim = !win.dim }

    readonly property var player: Media.player
    function findBuds() {
        var l = Bluetooth.devices.values
        for (var i = 0; i < l.length; i++) if (l[i].connected && l[i].batteryAvailable) return l[i]
        return null
    }
    readonly property var buds: findBuds()
    readonly property var bat: UPower.displayDevice
    readonly property real batPct: bat && bat.isPresent ? (bat.percentage > 1 ? bat.percentage / 100 : bat.percentage) : 0

    function week(d) {                   // ISO week
        var t = new Date(Date.UTC(d.getFullYear(), d.getMonth(), d.getDate()))
        t.setUTCDate(t.getUTCDate() + 4 - (t.getUTCDay() || 7))
        return Math.ceil(((t - Date.UTC(t.getUTCFullYear(), 0, 1)) / 86400000 + 1) / 7)
    }
    readonly property string hello: {
        var h = clock.date.getHours()
        return h < 5 ? "Good night" : h < 12 ? "Good morning" : h < 18 ? "Good afternoon" : "Good evening"
    }
    // widget id -> width in cells
    readonly property var kinds: ({ calendar: 1, cpu: 1, ram: 1, disk: 1, battery: 1, gpu: 1, player: 2, cava: 1, cat: 1, system: 3 })
    function shows(id) {
        if (id === "cava") return Settings.desktopViz && Cava.available
        if (id === "battery") return bat !== null && bat.isPresent
        if (id === "gpu") return Gpu.mode !== ""
        return kinds[id] !== undefined
    }

    // the 1920 x 1080 canvas, scaled to the screen
    Item {
        id: stage
        readonly property real s: Math.min(win.width / 1920, win.height / 1080)
        width: win.width / s
        height: win.height / s
        scale: s
        transformOrigin: Item.TopLeft

        Row {
            x: 182
            y: 150
            Num { text: Theme.hh(clock.date); font.pixelSize: 300 }
            Num { text: ":"; font.pixelSize: 300; opacity: Settings.blink && win.dim ? 0.2 : 1 }
            Num { text: Qt.formatDateTime(clock.date, "mm"); font.pixelSize: 300 }
        }
        Lb {
            x: 190
            y: 448
            px: 14
            text: win.en.toString(clock.date, "dddd · d MMMM") + " · week " + win.week(clock.date)
        }
        Text {
            x: 188
            y: 560
            textFormat: Text.StyledText
            text: win.hello + ",<br><font color=\"" + Theme.grey + "\">" + (Settings.name || Quickshell.env("USER") || "") + ".</font>"
            font.family: Theme.ui
            font.pixelSize: 54
            font.weight: Font.Light
            font.letterSpacing: -1
            lineHeight: 1.1
            color: Theme.fg
        }
        Row {
            x: 190
            y: 716
            spacing: 28
            Meta { icon: Theme.iBell; text: Notifs.count + (Notifs.count === 1 ? " notification" : " notifications") }
            Meta { visible: win.buds !== null; icon: Theme.iHeadphones; text: win.buds ? (win.buds.name + " · " + Math.round(win.buds.battery * 100) + "%") : "" }
            Meta { visible: win.player !== null && win.player.isPlaying; icon: Theme.iMusic; text: win.player ? (win.player.trackTitle || "") : "" }
        }

        // bento: left to right, a widget that doesn't fit the row starts the next one, more than 3 rows are left out
        Repeater {
            model: {
                var out = [], r = 0, c = 0, l = Settings.homeWidgets
                for (var i = 0; i < l.length; i++) {
                    var id = l[i], w = win.kinds[id]
                    if (!w || !win.shows(id)) continue
                    if (c + w > 3) { r++; c = 0 }
                    if (r > 2) break
                    out.push({ id: id, x: 1140 + c * 240, y: 150 + r * 240 })
                    c += w
                }
                return out
            }
            delegate: Loader {
                required property var modelData
                x: modelData.x
                y: modelData.y
                sourceComponent: ({ calendar: calendarW, cpu: cpuW, ram: ramW, disk: diskW, battery: batteryW, gpu: gpuW,
                                    player: playerW, cava: cavaW, cat: catW, system: systemW })[modelData.id] || null
            }
        }

        Component {
            id: calendarW
            W {
                Column {
                    x: 24
                    y: 24
                    width: parent.width - 48
                    Lb { text: win.en.monthName(clock.date.getMonth()) }
                    Num { topPadding: lead + 8; text: clock.date.getDate(); font.pixelSize: 118 }
                    Row {
                        width: parent.width
                        topPadding: 14
                        Repeater {
                            model: ["M", "T", "W", "T", "F", "S", "S"]
                            Text {
                                required property string modelData
                                required property int index
                                readonly property bool today: (clock.date.getDay() + 6) % 7 === index
                                width: parent.width / 7
                                horizontalAlignment: Text.AlignHCenter
                                text: modelData
                                font.family: Theme.mono
                                font.pixelSize: 11
                                color: today ? Theme.fill : Theme.grey
                                Rectangle {
                                    visible: parent.today
                                    anchors.bottom: parent.bottom
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    width: 10
                                    height: 2
                                    color: Theme.fill
                                }
                            }
                        }
                    }
                }
            }
        }
        Component { id: cpuW; RingW { f: SysStats.cpu; value: Math.round(SysStats.cpu * 100); label: "cpu %" } }
        Component {
            id: ramW
            RingW {
                f: SysStats.memTotal > 0 ? SysStats.memUsed / SysStats.memTotal : 0
                value: Math.round(f * 100)
                label: "ram · " + SysStats.memUsed.toFixed(1) + "g"
            }
        }
        Component {
            id: diskW
            RingW {
                readonly property var d: SysStats.disks.length ? SysStats.disks[0] : null
                f: d ? d.used / d.size : 0
                value: Math.round(f * 100)
                label: "disk %"
            }
        }
        Component {
            id: batteryW
            RingW {
                readonly property bool charging: win.bat && win.bat.state === UPowerDeviceState.Charging
                f: win.batPct
                value: Math.round(win.batPct * 100)
                label: charging ? "charging" : "battery"
                on: !charging && win.batPct <= Settings.batLow / 100 ? Theme.err : Theme.fill
            }
        }
        Component {
            id: gpuW
            W {
                round: true
                Column {
                    anchors.centerIn: parent
                    spacing: 14
                    Icon { anchors.horizontalCenter: parent.horizontalCenter; text: Theme.iGpu; font.pixelSize: 56; color: Theme.fill }
                    Lb { anchors.horizontalCenter: parent.horizontalCenter; text: "gpu · " + Gpu.mode }
                }
            }
        }
        // the player: the cover as dots in a circle, spinning while it plays
        Component {
            id: playerW
            W {
                span: 2
                Item {
                    id: art
                    x: 28
                    anchors.verticalCenter: parent.verticalCenter
                    width: 164
                    height: 164
                    property real turn: 0
                    Timer {
                        running: win.home && Media.playing
                        interval: 33
                        repeat: true
                        onTriggered: art.turn = (art.turn + 360 / 14 / 30) % 360
                    }
                    DotArt { anchors.fill: parent; rotation: art.turn; url: win.player ? win.player.trackArtUrl : ""; step: 6 }
                }
                // MPRIS doesn't push the position: poke it while the progress shows
                Timer {
                    running: win.home && Media.playing && Media.seekable
                    interval: 1000
                    repeat: true
                    onTriggered: win.player.positionChanged()
                }
                Column {
                    anchors.left: art.right
                    anchors.leftMargin: 26
                    anchors.right: parent.right
                    anchors.rightMargin: 28
                    anchors.verticalCenter: parent.verticalCenter
                    Lb { width: parent.width; elide: Text.ElideRight; text: "now playing · " + (win.player ? win.player.identity : "silence") }
                    Text {
                        width: parent.width
                        topPadding: 10
                        elide: Text.ElideRight
                        text: win.player ? (win.player.trackTitle || "Nothing on") : "Nothing on"
                        font.family: Theme.ui
                        font.pixelSize: 26
                        font.weight: Font.DemiBold
                        color: Theme.fg
                    }
                    Text {
                        width: parent.width
                        elide: Text.ElideRight
                        text: win.player ? (win.player.trackArtist || "") : ""
                        font.family: Theme.ui
                        font.pixelSize: 15
                        color: Theme.fgDim
                    }
                    Item { width: 1; height: 18 }
                    Seg {
                        width: parent.width
                        height: 6
                        n: 24
                        f: win.player && win.player.lengthSupported && win.player.length > 0 ? win.player.position / win.player.length : 0
                    }
                    Item { width: 1; height: 16 }
                    PlayControls { size: 22; play: 52 }
                }
            }
        }
        // cava as a round Glyph Matrix: bass in the middle, highs to the sides, columns grow up and down from the middle
        Component {
            id: cavaW
            W {
                round: true
                Grid {
                    anchors.centerIn: parent
                    columns: 15
                    spacing: 4
                    Repeater {
                        model: 15 * 15
                        Rectangle {
                            required property int index
                            readonly property int cx: index % 15 - 7
                            readonly property int cy: Math.floor(index / 15) - 7
                            readonly property int half: Math.floor(Math.sqrt(7.5 * 7.5 - cx * cx))   // half a column inside the circle
                            readonly property int n: Cava.values.length
                            readonly property real v: n ? Cava.values[Math.round(Math.abs(cx) / 7 * (n * 0.6 - 1))] || 0 : 0
                            width: 8
                            height: 8
                            radius: 4
                            // outside the circle: transparent, not invisible (Grid would close the gap)
                            color: Math.abs(cy) > half ? "transparent" : Math.abs(cy) < v * (half + 1) ? Theme.fill : Theme.s3
                        }
                    }
                }
            }
        }
        // the cat from the bar, big and as LED dots
        Component {
            id: catW
            W {
                CatLoop {
                    anchors.centerIn: parent
                    width: 180
                    height: 180
                    size: 120
                    layer.enabled: true
                    layer.effect: DotMask { step: 5 }
                }
            }
        }
        // system: numbers, and the cpu history as a dot matrix
        Component {
            id: systemW
            W {
                span: 3
                Grid {
                    x: 34
                    anchors.verticalCenter: parent.verticalCenter
                    columns: 2
                    columnSpacing: 10
                    rowSpacing: 22
                    Stat { label: "cpu"; value: Math.round(SysStats.cpu * 100) + "%" }
                    Stat { label: "mem"; value: SysStats.memUsed.toFixed(1) + "G" }
                    Stat { label: "up"; value: Math.floor(SysStats.uptime / 3600) + ":" + ("0" + Math.floor(SysStats.uptime / 60) % 60).slice(-2) }
                    Stat { label: "disk"; value: SysStats.disks.length ? Math.round(SysStats.disks[0].used / SysStats.disks[0].size * 100) + "%" : "-" }
                }
                Column {
                    x: 344
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - x - 34
                    spacing: 12
                    Lb { text: "cpu · 40 s" }
                    Spark { width: parent.width; height: 92; slots: 34; values: SysStats.history }
                }
            }
        }
    }

    // a bento cell: a square with radius 40, or a circle
    component W: Rectangle {
        property int span: 1
        property bool round: false
        width: span * 220 + (span - 1) * 20
        height: 220
        radius: round ? 110 : 40
        color: Theme.s1
        border.width: 1
        border.color: Theme.s2
    }
    // round widget: a ring of dots lit by f, the number and a label inside
    component RingW: Rectangle {
        id: rw
        property real f
        property string value
        property string label
        property color on: Theme.fill
        width: 220
        height: 220
        radius: 110
        color: Theme.s1
        border.width: 1
        border.color: Theme.s2
        Ring { anchors.fill: parent; anchors.margins: 12; f: rw.f; on: rw.on }
        Column {
            anchors.centerIn: parent
            Num { anchors.horizontalCenter: parent.horizontalCenter; text: rw.value; font.pixelSize: 72 }
            Lb { anchors.horizontalCenter: parent.horizontalCenter; topPadding: 8; text: rw.label }
        }
    }
    component Meta: Row {
        property string icon
        property string text
        spacing: 10
        Icon { anchors.verticalCenter: parent.verticalCenter; text: parent.icon; font.pixelSize: 16 }
        Lb { anchors.verticalCenter: parent.verticalCenter; text: parent.text }
    }
    component Stat: Column {
        property string label
        property string value
        width: 130
        Lb { text: parent.label }
        Num { topPadding: lead + 6; text: parent.value }
    }
}
