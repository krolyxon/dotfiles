import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland

// Month calendar under the clock pills. Monday first, ISO week numbers, scroll / arrows change month.
PanelWindow {
    id: win
    property bool opened: false
    signal closeRequested()

    visible: opened
    anchors { top: true; right: true }
    margins { top: 6; right: 8 }
    implicitWidth: 300
    implicitHeight: col.implicitHeight + 24
    exclusiveZone: 0
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "aurora-calendar"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

    HyprlandFocusGrab {
        windows: [win]
        active: win.opened
        onCleared: win.closeRequested()
    }

    SystemClock { id: clock; precision: SystemClock.Seconds }

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
        anchors.fill: parent
        color: Theme.bgA
        border.width: 2
        border.color: Theme.accent
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
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 12
            spacing: 8

            // big clock
            Text {
                text: Qt.formatDateTime(win.now, "HH:mm:ss")
                color: Theme.fg
                font.family: Theme.font
                font.pixelSize: 28
                font.bold: true
            }
            Text {
                text: Qt.formatDateTime(win.now, "dddd, d MMMM yyyy") + "  ·  w" + win.isoWeek(win.now)
                color: Theme.dim
                font.family: Theme.font
                font.pixelSize: Theme.fontSize - 1
            }

            Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Theme.line }

            RowLayout {
                Layout.fillWidth: true
                IconBtn { icon: Theme.iPrev; implicitHeight: 24; onClicked: win.shift(-1) }
                Text {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    text: Qt.formatDate(new Date(win.year, win.month, 1), "MMMM yyyy").toUpperCase()
                    color: Theme.accent
                    font.family: Theme.font
                    font.pixelSize: Theme.fontSize
                    font.bold: true
                    font.letterSpacing: 1.5
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: win.today()
                    }
                }
                IconBtn { icon: Theme.iNext; implicitHeight: 24; onClicked: win.shift(1) }
            }

            GridLayout {
                Layout.fillWidth: true
                columns: 8
                columnSpacing: 0
                rowSpacing: 0

                Repeater {
                    model: ["wk", "mo", "tu", "we", "th", "fr", "sa", "su"]
                    delegate: Text {
                        required property var modelData
                        required property int index
                        Layout.fillWidth: true
                        Layout.preferredHeight: 24
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        text: modelData
                        color: index === 0 ? Theme.line : (index >= 6 ? Theme.accentDim : Theme.dim)
                        font.family: Theme.font
                        font.pixelSize: Theme.fontSize - 2
                    }
                }

                Repeater {
                    model: 48
                    delegate: Rectangle {
                        id: cell
                        required property int index
                        readonly property bool isWeek: index % 8 === 0
                        // week-number cells use that row's Monday
                        readonly property var d: win.days[Math.floor(index / 8) * 7 + Math.max(0, (index % 8) - 1)]
                        readonly property bool inMonth: d.getMonth() === win.month
                        readonly property bool isToday: !isWeek && d.toDateString() === win.now.toDateString()
                        readonly property bool weekend: (index % 8) >= 6
                        Layout.fillWidth: true
                        Layout.preferredHeight: 28
                        color: isToday ? Theme.accent : "transparent"
                        Text {
                            anchors.centerIn: parent
                            text: cell.isWeek ? win.isoWeek(cell.d) : cell.d.getDate()
                            color: cell.isToday ? Theme.bg
                                   : cell.isWeek ? Theme.line
                                   : !cell.inMonth ? Theme.surfaceHi
                                   : cell.weekend ? Theme.accent : Theme.fg
                            font.family: Theme.font
                            font.pixelSize: cell.isWeek ? Theme.fontSize - 2 : Theme.fontSize
                            font.bold: cell.isToday
                        }
                    }
                }
            }
        }
    }
}
