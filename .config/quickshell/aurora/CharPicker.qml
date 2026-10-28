import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland

// Glyph picker (SUPER+grave, `chars` IPC): emoji, nerd font glyphs, unicode symbols, kaomoji, fancy text.
// Type to fuzzy search; arrows / Ctrl+HJKL move, Tab section, Ctrl+Left/Right group, Enter copies, Shift+Enter types it
// into the focused window, Ctrl+Enter collects into a buffer, Alt+Enter copies the codepoint.
// Looks like glyph's charms (github.com/Nebelung-cloud/glyph-rice, GPL-3.0, charms/Charms.qml): a card over the dimmed
// screen, search pill, section chips, tiles (the selected one white... here primary), the selection large at the bottom.
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
    WlrLayershell.namespace: "aurora-chars"
    WlrLayershell.keyboardFocus: opened ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    readonly property var sections: [
        { id: "all", label: "all", icon: Theme.iGrid, sets: ["emoji", "nerd", "sym"] },
        { id: "recent", label: "recent", icon: Theme.iHistory, sets: ["emoji", "nerd", "sym"] },
        { id: "emoji", label: "emoji", icon: Theme.iEmoji, sets: ["emoji"] },
        { id: "nerd", label: "nerd", icon: Theme.iFontGlyph, sets: ["nerd"] },
        { id: "sym", label: "symbols", icon: Theme.iSigma, sets: ["sym"] },
        { id: "kao", label: "kaomoji", icon: Theme.iKaomoji, sets: ["kao"] },
        { id: "fancy", label: "fancy", icon: Theme.iFancy, sets: [] }
    ]
    property int sec: 0
    property int grp: -1
    property string buffer: ""
    property var results: []
    property var hovered: null
    readonly property var section: sections[sec]
    readonly property bool listMode: section.id === "kao" || section.id === "fancy"
    readonly property int tone: Settings.charTone
    // groups of the shown set (single-set sections only)
    readonly property var groups: {
        if (!Chars.loaded || section.sets.length !== 1) return []
        var i = Chars.setIndex(section.sets[0])
        return i >= 0 ? Chars.sets[i].groups : []
    }
    readonly property var view: listMode ? list : grid
    readonly property var current: hovered ? hovered : (results.length && view.currentIndex >= 0 ? results[view.currentIndex] : null)

    onOpenedChanged: {
        if (!opened) return
        hovered = null
        buffer = ""
        filter.text = ""
        grp = -1
        Chars.load()
        sec = Chars.loaded && Chars.recent(1).length ? 1 : 0
        recompute()
        filter.forceActiveFocus()
    }
    onSecChanged: { grp = -1; recompute() }
    onGrpChanged: recompute()
    Connections {
        target: Chars
        function onLoadedChanged() {
            if (win.opened && Chars.recent(1).length && filter.text === "") win.sec = 1
            win.recompute()
        }
    }
    Timer { id: debounce; interval: 40; onTriggered: win.recompute() }

    function setList(id) {
        var out = []
        for (var i = 0; i < section.sets.length; i++) out.push(Chars.setIndex(section.sets[i]))
        return out
    }
    function recompute() {
        hovered = null
        var q = filter.text
        if (section.id === "fancy") results = Chars.fancy(q.trim() === "" ? "aurora" : q)
        else if (!Chars.loaded) results = []
        else if (section.id === "recent") {
            if (q.trim() === "") results = Chars.recent(300)
            else {
                var l = Chars.search(q, setList(), -1), out = []
                for (var i = 0; i < l.length; i++) if (Chars.counts[l[i].c]) out.push(l[i])
                results = out
            }
        } else if (section.id === "kao") {
            var k = Chars.search(q, setList(), grp)
            results = q.trim() === "" ? Chars.byUse(k) : k
        } else results = Chars.search(q, setList(), grp)
        grid.currentIndex = 0
        list.currentIndex = 0
        grid.positionViewAtBeginning()
        list.positionViewAtBeginning()
    }
    function cycleSection(d) { sec = (sec + d + sections.length) % sections.length }
    function cycleGroup(d) {
        if (!groups.length) return
        var n = groups.length + 1   // -1 = all
        grp = ((grp + 1 + d + n) % n) - 1
    }
    function outOf(it) { return section.id === "fancy" ? it.c : Chars.glyph(it, tone) }
    function codeOf(s) {
        var cps = Array.from(s)
        if (cps.length === 1) return "0x" + cps[0].codePointAt(0).toString(16).toUpperCase()
        return Chars.hex(s)
    }
    // how: copy | type | buffer | code
    function pick(it, how) {
        if (!it && buffer === "") return
        var s = it ? outOf(it) : ""
        if (it && section.id !== "fancy" && (how === "buffer" || buffer === "")) Chars.bump(it.c)
        if (how === "buffer") { buffer += s; return }
        if (how === "code") { Chars.copy(codeOf(s)); closeRequested(); return }
        if (buffer !== "") s = buffer
        closeRequested()
        if (how === "type" && Chars.hasWtype) Chars.type(s)
        else Chars.copy(s)
    }
    function move(key) {
        var v = view
        if (listMode) {
            if (key === Qt.Key_Up) v.decrementCurrentIndex()
            else if (key === Qt.Key_Down) v.incrementCurrentIndex()
            return
        }
        if (key === Qt.Key_Up) v.moveCurrentIndexUp()
        else if (key === Qt.Key_Down) v.moveCurrentIndexDown()
        else if (key === Qt.Key_Left) v.moveCurrentIndexLeft()
        else if (key === Qt.Key_Right) v.moveCurrentIndexRight()
    }
    function page(d) {
        var step = listMode ? 10 : grid.cols * Math.max(1, Math.floor(grid.height / grid.cellHeight))
        view.currentIndex = Math.max(0, Math.min(results.length - 1, view.currentIndex + d * step))
    }
    function fontOf(it) {
        return it && it.s !== undefined && Chars.sets[it.s] && Chars.sets[it.s].id === "emoji" ? "Noto Color Emoji" : Theme.font
    }

    Rectangle {
        anchors.fill: parent
        color: Theme.scrim
        opacity: win.t
        MouseArea { anchors.fill: parent; onClicked: win.closeRequested() }
    }

    Rectangle {
        id: card
        anchors.horizontalCenter: parent.horizontalCenter
        y: Math.round((parent.height - height) / 2) - 30 + 24 * (1 - win.t)
        width: Math.min(parent.width - 80, 960)
        height: Math.min(parent.height - 160, 740)
        opacity: win.t
        radius: 44
        color: Qt.rgba(Theme.s1.r, Theme.s1.g, Theme.s1.b, Theme.panelAlpha)
        border.width: 1
        border.color: Theme.s2
        MouseArea { anchors.fill: parent }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 30
            spacing: 14

            // ---- search + tone + close ----
            RowLayout {
                Layout.fillWidth: true
                spacing: 10
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 60
                    radius: 30
                    color: Theme.s2
                    Icon {
                        id: lens
                        x: 22
                        anchors.verticalCenter: parent.verticalCenter
                        text: Theme.iSearch
                        color: Theme.grey
                        font.pixelSize: 20
                    }
                    Text {
                        anchors.left: filter.left
                        anchors.right: count.left
                        anchors.verticalCenter: parent.verticalCenter
                        visible: filter.text === ""
                        elide: Text.ElideRight
                        text: win.section.id === "fancy" ? "Type some text" : "Search " + win.section.label + " (name, keyword, u+f0001, or paste a glyph)"
                        color: Theme.mute
                        font.family: Theme.ui
                        font.pixelSize: 18
                    }
                    TextInput {
                        id: filter
                        anchors.left: lens.right
                        anchors.leftMargin: 14
                        anchors.right: count.left
                        anchors.rightMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        color: Theme.fg
                        selectionColor: Theme.fill
                        selectedTextColor: Theme.fillFg
                        font.family: Theme.ui
                        font.pixelSize: 18
                        clip: true
                        cursorDelegate: Rectangle {
                            width: 2
                            color: Theme.live
                            visible: filter.activeFocus
                            Timer { running: filter.activeFocus; interval: 500; repeat: true; onTriggered: parent.opacity = 1 - parent.opacity }
                        }
                        onTextChanged: {
                            // recent is the landing page: typing there searches everything (used ones rank first anyway)
                            if (text !== "" && win.section.id === "recent") win.sec = 0
                            if (text === "") win.recompute(); else debounce.restart()
                        }
                        Keys.onEscapePressed: win.closeRequested()
                        Keys.onPressed: event => {
                            var k = event.key, m = event.modifiers
                            // ctrl+h/j/k/l move through the results like the arrows
                            var vim = { [Qt.Key_H]: Qt.Key_Left, [Qt.Key_J]: Qt.Key_Down, [Qt.Key_K]: Qt.Key_Up, [Qt.Key_L]: Qt.Key_Right }
                            if ((m & Qt.ControlModifier) && vim[k] !== undefined) {
                                win.hovered = null
                                win.move(vim[k])
                                event.accepted = true
                                return
                            }
                            if (k === Qt.Key_Return || k === Qt.Key_Enter) {
                                if (debounce.running) { debounce.stop(); win.recompute() }
                                var it = win.results[win.view.currentIndex]
                                if (m & Qt.ControlModifier) win.pick(it, "buffer")
                                else if (m & Qt.ShiftModifier) win.pick(it, "type")
                                else if (m & Qt.AltModifier) win.pick(it, "code")
                                else win.pick(it, "copy")
                            } else if (k === Qt.Key_Tab) win.cycleSection(1)
                            else if (k === Qt.Key_Backtab) win.cycleSection(-1)
                            else if ((m & Qt.ControlModifier) && (k === Qt.Key_Left || k === Qt.Key_Right)) win.cycleGroup(k === Qt.Key_Left ? -1 : 1)
                            else if ((m & Qt.AltModifier) && k >= Qt.Key_1 && k < Qt.Key_1 + win.sections.length) win.sec = k - Qt.Key_1
                            else if (k === Qt.Key_Up || k === Qt.Key_Down || (!win.listMode && (k === Qt.Key_Left || k === Qt.Key_Right))) {
                                win.hovered = null
                                win.move(k)
                            } else if (k === Qt.Key_PageDown) win.page(1)
                            else if (k === Qt.Key_PageUp) win.page(-1)
                            else if (k === Qt.Key_Backspace && filter.text === "" && win.buffer !== "")
                                win.buffer = Array.from(win.buffer).slice(0, -1).join("")
                            else return
                            event.accepted = true
                        }
                    }
                    Lb {
                        id: count
                        anchors.right: parent.right
                        anchors.rightMargin: 22
                        anchors.verticalCenter: parent.verticalCenter
                        text: win.results.length
                    }
                }
                // skin tone: the raised hand in each tone, click to choose (persisted)
                Row {
                    visible: Chars.loaded && (win.section.id === "emoji" || win.section.id === "all" || win.section.id === "recent")
                    spacing: 2
                    Repeater {
                        model: 6
                        delegate: Rectangle {
                            required property int index
                            readonly property var hand: Chars.byChar["✋"]
                            width: 40
                            height: 40
                            radius: 20
                            color: Settings.charTone === index ? Theme.fill : (tm.containsMouse ? Theme.s3 : "transparent")
                            Text {
                                anchors.centerIn: parent
                                text: parent.hand ? Chars.glyph(parent.hand, parent.index) : ""
                                font.family: "Noto Color Emoji"
                                font.pixelSize: 17
                            }
                            MouseArea {
                                id: tm
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: { Settings.charTone = parent.index; filter.forceActiveFocus() }
                            }
                        }
                    }
                }
                IconBtn { implicitHeight: 48; icon: Theme.iClose; onClicked: win.closeRequested() }
            }

            // ---- sections ----
            Row {
                Layout.fillWidth: true
                spacing: 2
                Repeater {
                    model: win.sections
                    delegate: Chip {
                        required property var modelData
                        required property int index
                        text: modelData.label
                        selected: win.sec === index
                        onClicked: { win.sec = index; filter.forceActiveFocus() }
                    }
                }
            }

            // ---- groups of the section ----
            ListView {
                id: chips
                Layout.fillWidth: true
                implicitHeight: 32
                visible: win.groups.length > 0
                orientation: ListView.Horizontal
                spacing: 4
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                model: win.groups.length ? ["all"].concat(win.groups) : []
                currentIndex: win.grp + 1
                onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)
                delegate: Chip {
                    required property var modelData
                    required property int index
                    height: 32
                    px: 10
                    filled: true
                    text: modelData
                    selected: win.grp === index - 1
                    onClicked: { win.grp = index - 1; filter.forceActiveFocus() }
                }
            }

            // ---- results ----
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true

                GridView {
                    id: grid
                    anchors.fill: parent
                    visible: !win.listMode
                    readonly property int cols: Math.max(1, Math.floor(width / 58))
                    cellWidth: Math.floor(width / cols)
                    cellHeight: 58
                    clip: true
                    model: win.listMode ? 0 : win.results.length
                    boundsBehavior: Flickable.StopAtBounds
                    highlightMoveDuration: 0
                    keyNavigationWraps: false
                    cacheBuffer: 400
                    delegate: Rectangle {
                        id: cell
                        required property int index
                        readonly property var it: win.results[index]
                        readonly property bool selected: grid.currentIndex === index
                        width: grid.cellWidth - 4
                        height: grid.cellHeight - 4
                        radius: 18
                        color: selected ? Theme.fill : (gm.containsMouse ? Theme.s2 : "transparent")
                        Text {
                            anchors.centerIn: parent
                            text: cell.it ? Chars.glyph(cell.it, win.tone) : ""
                            color: cell.selected ? Theme.fillFg : Theme.fg
                            font.family: win.fontOf(cell.it)
                            font.pixelSize: 26
                        }
                        MouseArea {
                            id: gm
                            anchors.fill: parent
                            hoverEnabled: true
                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                            cursorShape: Qt.PointingHandCursor
                            onContainsMouseChanged: win.hovered = containsMouse ? cell.it : null
                            onClicked: mouse => {
                                grid.currentIndex = cell.index
                                win.pick(cell.it, mouse.button === Qt.RightButton ? "buffer" : "copy")
                            }
                        }
                    }
                }

                ListView {
                    id: list
                    anchors.fill: parent
                    visible: win.listMode
                    clip: true
                    model: win.listMode ? win.results.length : 0
                    spacing: 2
                    boundsBehavior: Flickable.StopAtBounds
                    highlightMoveDuration: 0
                    delegate: Rectangle {
                        id: row
                        required property int index
                        readonly property var it: win.results[index]
                        readonly property bool selected: list.currentIndex === index
                        width: list.width
                        height: 52
                        radius: 26
                        color: selected ? Theme.fill : (lm.containsMouse ? Theme.s2 : "transparent")
                        Text {
                            anchors.left: parent.left
                            anchors.leftMargin: 22
                            anchors.right: tag.left
                            anchors.rightMargin: 12
                            anchors.verticalCenter: parent.verticalCenter
                            text: row.it ? row.it.c : ""
                            elide: Text.ElideRight
                            maximumLineCount: 1
                            color: row.selected ? Theme.fillFg : Theme.fg
                            font.family: Theme.ui
                            font.pixelSize: 18
                        }
                        Lb {
                            id: tag
                            anchors.right: parent.right
                            anchors.rightMargin: 22
                            anchors.verticalCenter: parent.verticalCenter
                            px: 10
                            text: row.it ? (win.section.id === "fancy" ? row.it.n : row.it.k) : ""
                            color: row.selected ? Theme.fillFg : Theme.grey
                        }
                        MouseArea {
                            id: lm
                            anchors.fill: parent
                            hoverEnabled: true
                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                            cursorShape: Qt.PointingHandCursor
                            onContainsMouseChanged: win.hovered = containsMouse ? row.it : null
                            onClicked: mouse => {
                                list.currentIndex = row.index
                                win.pick(row.it, mouse.button === Qt.RightButton ? "buffer" : "copy")
                            }
                        }
                    }
                }

                Lb {
                    anchors.centerIn: parent
                    visible: win.results.length === 0
                    color: Theme.mute
                    text: !Chars.loaded && win.section.id !== "fancy" ? "loading glyphs…"
                        : (win.section.id === "recent" && filter.text === "" ? "nothing used yet" : "no matches")
                }
            }

            // ---- the selected / hovered glyph, large ----
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 92
                radius: 30
                color: Theme.s2

                Rectangle {
                    id: big
                    visible: !win.listMode
                    x: 12
                    anchors.verticalCenter: parent.verticalCenter
                    width: visible ? 68 : 0
                    height: 68
                    radius: 34
                    color: Theme.s3
                    Text {
                        anchors.centerIn: parent
                        text: win.current ? Chars.glyph(win.current, win.tone) : ""
                        color: Theme.fill
                        font.family: win.fontOf(win.current)
                        font.pixelSize: 36
                    }
                }
                Column {
                    anchors.left: big.right
                    anchors.leftMargin: 16
                    anchors.right: buf.left
                    anchors.rightMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 4
                    Text {
                        width: parent.width
                        text: win.current ? win.current.n : ""
                        elide: Text.ElideRight
                        color: Theme.fg
                        font.family: Theme.ui
                        font.pixelSize: 16
                        font.weight: Font.DemiBold
                    }
                    Lb {
                        width: parent.width
                        visible: win.current !== null && win.section.id !== "fancy"
                        px: 10
                        color: Theme.fill
                        text: {
                            var c = win.current
                            if (!c || c.s === undefined || !Chars.sets[c.s]) return ""
                            var st = Chars.sets[c.s]
                            return (st.id === "kao" ? "" : Chars.hex(Chars.glyph(c, win.tone)) + " · ")
                                + st.label + " · " + st.groups[c.g]
                        }
                        elide: Text.ElideRight
                    }
                    Lb {
                        width: parent.width
                        visible: text !== ""
                        px: 10
                        text: win.current && win.current.k && win.section.id !== "kao" ? win.current.k : ""
                        elide: Text.ElideRight
                    }
                }
                Row {   // collected with ctrl+enter / right click
                    id: buf
                    anchors.right: parent.right
                    anchors.rightMargin: 22
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 10
                    visible: win.buffer !== ""
                    width: visible ? implicitWidth : 0
                    Icon {
                        anchors.verticalCenter: parent.verticalCenter
                        text: Theme.iBuffer
                        color: Theme.live
                        font.pixelSize: 18
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        width: Math.min(implicitWidth, 220)
                        text: win.buffer
                        elide: Text.ElideLeft
                        color: Theme.fg
                        font.family: Theme.font
                        font.pixelSize: 20
                    }
                }
            }
        }
    }

    Row {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: card.bottom
        anchors.topMargin: 26
        opacity: win.t
        spacing: 30
        Repeater {
            model: ["↵ copy"].concat(Chars.hasWtype ? ["shift ↵ type"] : []).concat(["ctrl ↵ collect", "alt ↵ code", "ctrl hjkl move", "tab section", "ctrl ←→ group", "esc close"])
            Lb { required property string modelData; text: modelData }
        }
    }
}
