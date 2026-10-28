import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland

// Session / power actions (SUPER+Escape, the panel's power button). The screen goes nearly black, the actions are a
// column of Doto words: the selected one large with the live dot, the rest dim; uptime in a ring of dots on the right.
// Up/Down/Tab or hover pick, Enter/click runs, typing filters, Esc or a click on the background closes.
// Destructive ones need a second Enter/click within 3s (the word turns the error colour).
// After glyph-rice (github.com/Nebelung-cloud/glyph-rice, GPL-3.0), power/Power.qml.
PanelWindow {
    id: win
    property bool opened: false
    signal closeRequested()

    property real t: opened ? 1 : 0
    Behavior on t { NumberAnimation { duration: Theme.t; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.glide } }

    visible: t > 0
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "aurora-power"
    WlrLayershell.keyboardFocus: opened ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    readonly property var actions: Session.actions
    // short words for the big type (Session's labels stay for the runner)
    readonly property var words: ({ leave: "log out", renew: "reload", display: "screen off", shutdown: "shut down" })
    function word(a) { return words[a.id] || a.label }

    property int current: 0
    property string armed: ""
    Timer { id: disarm; interval: 3000; onTriggered: win.armed = "" }

    onOpenedChanged: {
        if (!opened) return
        filter.text = ""
        current = Math.max(0, shown.indexOf(shown.filter(a => a.id === "shutdown")[0]))
        armed = ""
        filter.forceActiveFocus()
    }

    readonly property var shown: {
        var q = filter.text.toLowerCase().trim(), out = []
        for (var i = 0; i < actions.length; i++) {
            var sc = Math.max(Fuzzy.score(actions[i].label, q), Fuzzy.score(word(actions[i]), q))
            if (sc > 0) out.push({ a: actions[i], sc: sc, i: i })
        }
        if (q !== "") out.sort(function (x, y) { return y.sc - x.sc || x.i - y.i })
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

    SystemClock { id: clock; precision: SystemClock.Minutes }

    Rectangle {
        anchors.fill: parent
        color: Theme.fade(Theme.bg, 0.96)
        opacity: win.t
        MouseArea { anchors.fill: parent; onClicked: win.closeRequested() }
    }

    // typing filters; the field itself stays invisible, the filter shows as a label
    TextInput {
        id: filter
        width: 0
        height: 0
        opacity: 0
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

    // the 1920 x 1080 canvas, scaled to the screen
    Item {
        id: stage
        readonly property real s: Math.min(win.width / 1920, win.height / 1080)
        width: win.width / s
        height: win.height / s
        scale: s
        transformOrigin: Item.TopLeft
        opacity: win.t

        Lb {
            x: 240
            y: 90
            visible: filter.text !== ""
            px: 14
            color: Theme.fg
            text: "filter · " + filter.text + (win.shown.length ? "" : " · no match")
        }

        Column {
            x: 240 - 30 * (1 - win.t)
            anchors.verticalCenter: parent.verticalCenter
            spacing: 20
            Repeater {
                model: win.shown
                Row {
                    id: it
                    required property var modelData
                    required property int index
                    readonly property bool on: win.current === index
                    readonly property bool isArmed: win.armed === modelData.id
                    spacing: 30
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: it.on
                        width: 30
                        height: 30
                        radius: 15
                        color: it.isArmed ? Theme.err : Theme.live
                    }
                    Num {
                        text: win.word(it.modelData).toUpperCase()
                        font.pixelSize: it.on ? 128 : 56
                        color: it.isArmed ? Theme.err : it.on ? Theme.fg : Theme.mute
                        Behavior on font.pixelSize {
                            enabled: Theme.motion
                            NumberAnimation { duration: Theme.t; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.glide }
                        }
                        Behavior on color { enabled: Theme.motion; ColorAnimation { duration: Theme.t } }
                    }
                    Lb {
                        visible: it.isArmed
                        anchors.verticalCenter: parent.verticalCenter
                        px: 14
                        color: Theme.err
                        text: "↵ again to " + win.word(it.modelData)
                    }
                    HoverHandler { onHoveredChanged: if (hovered && win.current !== it.index) { win.current = it.index; win.armed = "" } }
                    TapHandler { onTapped: win.trigger(it.index) }
                }
            }
        }

        Item {
            x: stage.width - 200 - 440
            anchors.verticalCenter: parent.verticalCenter
            width: 440
            height: 440
            Ring { anchors.fill: parent; n: 60; dot: 10; f: SysStats.uptime / (6 * 3600) }
            Column {
                anchors.centerIn: parent
                Lb { anchors.horizontalCenter: parent.horizontalCenter; text: "uptime" }
                Num {
                    anchors.horizontalCenter: parent.horizontalCenter
                    topPadding: lead + 10
                    bottomPadding: lead + 10
                    text: Math.floor(SysStats.uptime / 3600) + ":" + ("0" + Math.floor(SysStats.uptime / 60) % 60).slice(-2)
                    font.pixelSize: 104
                }
                Lb {
                    anchors.horizontalCenter: parent.horizontalCenter
                    readonly property int n: Hyprland.toplevels.values.length
                    text: n + (n === 1 ? " window open" : " windows open")
                }
            }
        }

        Row {
            x: 240
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 70
            spacing: 34
            Lb { text: "↑↓ select" }
            Lb { text: "↵ confirm" }
            Lb { text: "type to filter" }
            Lb { text: "esc cancel" }
        }
    }
}
