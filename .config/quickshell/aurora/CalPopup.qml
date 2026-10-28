import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland

// Month calendar under the bar clock (top centre): Doto month, Monday first, ISO week numbers, today in a primary circle.
// Scroll / arrows change the month, up / down the year, space = back to today, Esc closes.
// After glyph-rice (github.com/Nebelung-cloud/glyph-rice, GPL-3.0), cal/Cal.qml.
PanelWindow {
    id: win
    property bool opened: false
    signal closeRequested()

    property real t: opened ? 1 : 0
    Behavior on t { NumberAnimation { duration: Theme.t; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.glide } }

    visible: t > 0
    anchors.top: true
    margins.top: 6
    implicitWidth: card.width
    implicitHeight: card.height + 20      // room for the slide
    exclusiveZone: 0
    color: "transparent"
    mask: Region { item: card }
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "aurora-calendar"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

    HyprlandFocusGrab {
        windows: [win]
        active: win.opened
        onCleared: win.closeRequested()
    }

    SystemClock { id: clock; precision: SystemClock.Minutes }
    readonly property var en: Qt.locale("en_US")

    property int year: 0
    property int month: 0                 // 0..11
    function today() {
        var d = new Date()
        year = d.getFullYear()
        month = d.getMonth()
    }
    function shift(n) {
        var m = month + n
        year += Math.floor(m / 12)
        month = ((m % 12) + 12) % 12
    }
    onOpenedChanged: if (opened) today()

    function isoWeek(d) {
        var t = new Date(Date.UTC(d.getFullYear(), d.getMonth(), d.getDate()))
        var day = t.getUTCDay() || 7
        t.setUTCDate(t.getUTCDate() + 4 - day)
        var y0 = new Date(Date.UTC(t.getUTCFullYear(), 0, 1))
        return Math.ceil(((t - y0) / 86400000 + 1) / 7)
    }
    // 6 rows x 7 days starting on the Monday on/before the 1st
    readonly property var days: {
        var first = new Date(year, month, 1)
        var start = new Date(year, month, 1 - ((first.getDay() + 6) % 7))
        var out = []
        for (var i = 0; i < 42; i++)
            out.push(new Date(start.getFullYear(), start.getMonth(), start.getDate() + i))
        return out
    }
    readonly property var now: clock.date

    Rectangle {
        id: card
        y: -16 * (1 - win.t)
        opacity: win.t
        width: 384
        height: col.implicitHeight + 44
        radius: 36
        color: Qt.rgba(Theme.s1.r, Theme.s1.g, Theme.s1.b, Theme.panelAlpha)
        border.width: 1
        border.color: Theme.s2
        focus: true
        Keys.onEscapePressed: win.closeRequested()
        Keys.onLeftPressed: win.shift(-1)
        Keys.onRightPressed: win.shift(1)
        Keys.onUpPressed: win.shift(-12)
        Keys.onDownPressed: win.shift(12)
        Keys.onSpacePressed: win.today()

        MouseArea {
            anchors.fill: parent
            onWheel: w => win.shift(w.angleDelta.y > 0 ? -1 : 1)
        }

        ColumnLayout {
            id: col
            x: 22
            y: 22
            width: parent.width - 44
            spacing: 14

            Lb {
                Layout.leftMargin: 6
                px: 10
                text: win.en.toString(win.now, "dddd · d MMMM yyyy") + " · week " + win.isoWeek(win.now)
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.leftMargin: 6
                spacing: 12
                Num {
                    text: win.en.standaloneMonthName(win.month, Locale.ShortFormat)
                    font.pixelSize: 44
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: win.today()
                    }
                }
                Lb {
                    Layout.alignment: Qt.AlignVCenter
                    text: win.year
                }
                Item { Layout.fillWidth: true }
                IconBtn { implicitHeight: 40; icon: Theme.iChevronLeft; onClicked: win.shift(-1) }
                IconBtn { implicitHeight: 40; icon: Theme.iChevron; onClicked: win.shift(1) }
            }

            Grid {
                id: grid
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                columns: 8
                readonly property real cw: width / 8

                Repeater {
                    model: ["wk", "m", "t", "w", "t", "f", "s", "s"]
                    delegate: Lb {
                        required property var modelData
                        required property int index
                        width: grid.cw
                        height: 28
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        text: modelData
                        px: 10
                        color: index === 0 ? Theme.mute : Theme.grey
                    }
                }
                Repeater {
                    model: 48
                    delegate: Item {
                        id: cell
                        required property int index
                        readonly property bool isWeek: index % 8 === 0
                        // week-number cells use that row's Monday
                        readonly property var d: win.days[Math.floor(index / 8) * 7 + Math.max(0, (index % 8) - 1)]
                        readonly property bool inMonth: d.getMonth() === win.month
                        readonly property bool isToday: !isWeek && d.toDateString() === win.now.toDateString()
                        readonly property bool weekend: (index % 8) >= 6
                        width: grid.cw
                        height: 40
                        Rectangle {
                            visible: cell.isToday
                            anchors.centerIn: parent
                            width: 34
                            height: 34
                            radius: 17
                            color: Theme.fill
                        }
                        Text {
                            anchors.centerIn: parent
                            text: cell.isWeek ? win.isoWeek(cell.d) : cell.d.getDate()
                            color: cell.isToday ? Theme.fillFg
                                   : cell.isWeek ? Theme.mute
                                   : !cell.inMonth ? Theme.mute
                                   : cell.weekend ? Theme.grey : Theme.fg
                            font.family: Theme.mono
                            font.pixelSize: cell.isWeek ? 10 : 13
                            font.bold: cell.isToday
                        }
                    }
                }
            }
        }
    }
}
