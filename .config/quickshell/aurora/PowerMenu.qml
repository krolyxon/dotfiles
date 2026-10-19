import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland

// Session / power actions (was the fuzzel `sysact` script). Type to fuzzy filter, Up/Down/Tab pick,
// Enter runs, Esc closes. Destructive ones need a second Enter/click ("sure?").
PanelWindow {
    id: win
    property bool opened: false
    signal closeRequested()

    visible: opened
    implicitWidth: 300
    // fixed to the full list so the centred window doesn't jump while filtering
    implicitHeight: 24 + 36 + actions.length * 32 + 22
    exclusiveZone: 0
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "aurora-power"
    WlrLayershell.keyboardFocus: opened ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    HyprlandFocusGrab {
        windows: [win]
        active: win.opened
        onCleared: win.closeRequested()
    }

    readonly property var actions: Session.actions

    property int current: 0
    property string armed: ""
    Timer { id: disarm; interval: 3000; onTriggered: win.armed = "" }

    onOpenedChanged: {
        if (!opened) return
        filter.text = ""
        current = 0
        armed = ""
        filter.forceActiveFocus()
    }

    readonly property var shown: {
        var q = filter.text.toLowerCase().trim(), out = []
        for (var i = 0; i < actions.length; i++) {
            var sc = Fuzzy.score(actions[i].label, q)
            if (sc > 0) out.push({ a: actions[i], sc: sc, i: i })
        }
        out.sort(function (x, y) { return y.sc - x.sc || x.i - y.i })
        var res = []
        for (var j = 0; j < out.length; j++) res.push(out[j].a)
        return res
    }

    function trigger(i) {
        var a = shown[i]
        if (!a) return
        current = i
        if (a.confirm && armed !== a.id) { armed = a.id; disarm.restart(); return }
        armed = ""
        closeRequested()
        Session.run(a.id)
    }

    Rectangle {
        anchors.fill: parent
        color: Theme.bgA
        border.width: 2
        border.color: Theme.accent

        ColumnLayout {
            id: col
            anchors.fill: parent
            anchors.margins: 12
            spacing: 2

            Rectangle {
                Layout.fillWidth: true
                Layout.bottomMargin: 6
                implicitHeight: 30
                color: Theme.surface
                border.width: 1
                border.color: filter.activeFocus ? Theme.accent : Theme.line
                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    text: Theme.iPower
                    color: Theme.dim
                    font.family: Theme.font
                    font.pixelSize: Theme.fontSize
                }
                TextInput {
                    id: filter
                    anchors.fill: parent
                    anchors.leftMargin: 32
                    anchors.rightMargin: 10
                    verticalAlignment: TextInput.AlignVCenter
                    color: Theme.fg
                    selectionColor: Theme.accent
                    selectedTextColor: Theme.bg
                    font.family: Theme.font
                    font.pixelSize: Theme.fontSize
                    clip: true
                    onTextChanged: { win.current = 0; win.armed = "" }
                    Keys.onEscapePressed: win.closeRequested()
                    Keys.onReturnPressed: win.trigger(win.current)
                    Keys.onEnterPressed: win.trigger(win.current)
                    Keys.onPressed: event => {
                        var n = win.shown.length
                        if (!n) return
                        if (event.key === Qt.Key_Down || event.key === Qt.Key_Tab) {
                            win.current = (win.current + 1) % n; win.armed = ""; event.accepted = true
                        } else if (event.key === Qt.Key_Up || event.key === Qt.Key_Backtab) {
                            win.current = (win.current + n - 1) % n; win.armed = ""; event.accepted = true
                        }
                    }
                }
            }

            Repeater {
                model: win.shown
                delegate: Rectangle {
                    id: row
                    required property var modelData
                    required property int index
                    readonly property bool selected: win.current === index
                    readonly property bool isArmed: win.armed === modelData.id
                    Layout.fillWidth: true
                    implicitHeight: 30
                    color: isArmed ? Theme.err : (selected ? Theme.surfaceHi : (rm.containsMouse ? Theme.surface : "transparent"))
                    border.width: selected ? 1 : 0
                    border.color: isArmed ? Theme.err : Theme.accent

                    Rectangle {   // selection marker, like ClipWindow
                        visible: row.selected
                        width: 2
                        height: parent.height
                        color: row.isArmed ? Theme.bg : Theme.accent
                    }
                    Text {
                        id: ico
                        anchors.left: parent.left
                        anchors.leftMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        width: 18
                        text: row.modelData.icon
                        color: row.isArmed ? Theme.bg : Theme.accent
                        font.family: Theme.font
                        font.pixelSize: Theme.fontSize + 2
                    }
                    Text {
                        anchors.left: ico.right
                        anchors.leftMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        text: row.isArmed ? row.modelData.label + "  sure?" : row.modelData.label
                        color: row.isArmed ? Theme.bg : Theme.fg
                        font.family: Theme.font
                        font.pixelSize: Theme.fontSize
                    }
                    MouseArea {
                        id: rm
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: if (win.current !== row.index) { win.current = row.index; win.armed = "" }
                        onClicked: win.trigger(row.index)
                    }
                }
            }

            Item { Layout.fillHeight: true }

            Text {
                Layout.fillWidth: true
                Layout.topMargin: 6
                text: win.shown.length ? "type filter   enter run   esc close" : "no match"
                color: win.shown.length ? Theme.dim : Theme.err
                font.family: Theme.font
                font.pixelSize: Theme.fontSize - 2
            }
        }
    }
}
