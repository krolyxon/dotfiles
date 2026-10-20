import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland

// Glyph picker (SUPER+grave, `chars` IPC): emoji, nerd font glyphs, unicode symbols, kaomoji, fancy text.
// Type to fuzzy search; arrows move, Tab section, Ctrl+Left/Right group, Enter copies, Shift+Enter types it
// into the focused window, Ctrl+Enter collects into a buffer, Alt+Enter copies the codepoint.
PanelWindow {
    id: win
    property bool opened: false
    signal closeRequested()

    visible: opened
    implicitWidth: 780
    implicitHeight: 590
    exclusiveZone: 0
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "aurora-chars"
    WlrLayershell.keyboardFocus: opened ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    HyprlandFocusGrab {
        windows: [win]
        active: win.opened
        onCleared: win.closeRequested()
    }

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
        color: Theme.bgA
        border.width: 2
        border.color: Theme.accent

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 8

            // ---- search + tone + close ----
            RowLayout {
                Layout.fillWidth: true
                spacing: 6
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 30
                    color: Theme.surface
                    border.width: 1
                    border.color: filter.activeFocus ? Theme.accent : Theme.line
                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        text: Theme.iSearch
                        color: Theme.dim
                        font.family: Theme.font
                        font.pixelSize: Theme.fontSize
                    }
                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: 32
                        anchors.verticalCenter: parent.verticalCenter
                        visible: filter.text === ""
                        text: win.section.id === "fancy" ? "type some text" : "search " + win.section.label + "  (name, keyword, u+f0001, or paste a glyph)"
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
                        onTextChanged: {
                            // recent is the landing page: typing there searches everything (used ones rank first anyway)
                            if (text !== "" && win.section.id === "recent") win.sec = 0
                            if (text === "") win.recompute(); else debounce.restart()
                        }
                        Keys.onEscapePressed: win.closeRequested()
                        Keys.onPressed: event => {
                            var k = event.key, m = event.modifiers
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
                }
                Text {
                    text: win.results.length
                    color: Theme.dim
                    font.family: Theme.font
                    font.pixelSize: Theme.fontSize - 1
                }
                // skin tone: the raised hand in each tone, click to choose (persisted)
                Row {
                    visible: Chars.loaded && (win.section.id === "emoji" || win.section.id === "all" || win.section.id === "recent")
                    spacing: 0
                    Repeater {
                        model: 6
                        delegate: Rectangle {
                            required property int index
                            readonly property var hand: Chars.byChar["✋"]
                            width: 26
                            height: 30
                            color: Settings.charTone === index ? Theme.surfaceHi : (tm.containsMouse ? Theme.surface : "transparent")
                            border.width: Settings.charTone === index ? 1 : 0
                            border.color: Theme.accent
                            Text {
                                anchors.centerIn: parent
                                text: parent.hand ? Chars.glyph(parent.hand, parent.index) : ""
                                font.family: "Noto Color Emoji"
                                font.pixelSize: 15
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
                IconBtn { icon: Theme.iClose; onClicked: win.closeRequested() }
            }

            // ---- sections ----
            RowLayout {
                Layout.fillWidth: true
                spacing: 2
                Repeater {
                    model: win.sections
                    delegate: Rectangle {
                        id: tab
                        required property var modelData
                        required property int index
                        readonly property bool active: win.sec === index
                        Layout.fillWidth: true
                        implicitHeight: 28
                        color: active ? Theme.surfaceHi : (sm.containsMouse ? Theme.surface : "transparent")
                        Row {
                            anchors.centerIn: parent
                            spacing: 6
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: tab.modelData.icon
                                color: tab.active ? Theme.accent : Theme.dim
                                font.family: Theme.font
                                font.pixelSize: Theme.fontSize + 2
                            }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: tab.modelData.label.toUpperCase()
                                color: tab.active ? Theme.fg : Theme.dim
                                font.family: Theme.font
                                font.pixelSize: Theme.fontSize - 2
                                font.letterSpacing: 1.2
                                font.bold: tab.active
                            }
                        }
                        Rectangle {   // waybar-style underline
                            anchors.bottom: parent.bottom
                            width: parent.width
                            height: tab.active ? 2 : 1
                            color: tab.active ? Theme.accent : Theme.line
                        }
                        MouseArea {
                            id: sm
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: { win.sec = tab.index; filter.forceActiveFocus() }
                        }
                    }
                }
            }

            // ---- groups of the section ----
            ListView {
                id: chips
                Layout.fillWidth: true
                implicitHeight: 22
                visible: win.groups.length > 0
                orientation: ListView.Horizontal
                spacing: 4
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                model: win.groups.length ? ["all"].concat(win.groups) : []
                currentIndex: win.grp + 1
                onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)
                delegate: Rectangle {
                    id: chip
                    required property var modelData
                    required property int index
                    readonly property bool active: win.grp === index - 1
                    width: ct.implicitWidth + 16
                    height: 22
                    color: active ? Theme.accent : (cm.containsMouse ? Theme.surfaceHi : Theme.surface)
                    border.width: 1
                    border.color: active ? Theme.accent : Theme.line
                    Text {
                        id: ct
                        anchors.centerIn: parent
                        text: chip.modelData.toLowerCase()
                        color: chip.active ? Theme.bg : Theme.fg
                        font.family: Theme.font
                        font.pixelSize: Theme.fontSize - 2
                    }
                    MouseArea {
                        id: cm
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: { win.grp = chip.index - 1; filter.forceActiveFocus() }
                    }
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
                    readonly property int cols: Math.max(1, Math.floor(width / 50))
                    cellWidth: Math.floor(width / cols)
                    cellHeight: 50
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
                        width: grid.cellWidth - 2
                        height: grid.cellHeight - 2
                        color: selected ? Theme.surfaceHi : (gm.containsMouse ? Theme.surface : "transparent")
                        border.width: selected ? 1 : 0
                        border.color: Theme.accent
                        Text {
                            anchors.centerIn: parent
                            text: cell.it ? Chars.glyph(cell.it, win.tone) : ""
                            color: Theme.fg
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
                        height: 34
                        color: selected ? Theme.surfaceHi : (lm.containsMouse ? Theme.surface : "transparent")
                        border.width: selected ? 1 : 0
                        border.color: Theme.accent
                        Rectangle {
                            visible: row.selected
                            width: 2
                            height: parent.height
                            color: Theme.accent
                        }
                        Text {
                            anchors.left: parent.left
                            anchors.leftMargin: 12
                            anchors.right: tag.left
                            anchors.rightMargin: 12
                            anchors.verticalCenter: parent.verticalCenter
                            text: row.it ? row.it.c : ""
                            elide: Text.ElideRight
                            maximumLineCount: 1
                            color: Theme.fg
                            font.family: Theme.font
                            font.pixelSize: Theme.fontSize + 4
                        }
                        Text {
                            id: tag
                            anchors.right: parent.right
                            anchors.rightMargin: 12
                            anchors.verticalCenter: parent.verticalCenter
                            text: row.it ? (win.section.id === "fancy" ? row.it.n : row.it.k) : ""
                            color: row.selected ? Theme.accent : Theme.dim
                            font.family: Theme.font
                            font.pixelSize: Theme.fontSize - 1
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

                Text {
                    anchors.centerIn: parent
                    visible: win.results.length === 0
                    text: !Chars.loaded && win.section.id !== "fancy" ? "loading glyphs..."
                        : (win.section.id === "recent" && filter.text === "" ? "nothing used yet" : "no matches")
                    color: Theme.dim
                    font.family: Theme.font
                    font.pixelSize: Theme.fontSize
                }
            }

            // ---- preview of the selected / hovered glyph ----
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 62
                color: Theme.surface
                border.width: 1
                border.color: Theme.line

                Rectangle {   // big glyph
                    id: big
                    visible: !win.listMode
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    width: visible ? height : 0
                    color: "transparent"
                    border.width: 1
                    border.color: Theme.line
                    Text {
                        anchors.centerIn: parent
                        text: win.current ? Chars.glyph(win.current, win.tone) : ""
                        color: Theme.accent
                        font.family: win.fontOf(win.current)
                        font.pixelSize: 38
                    }
                }
                Column {
                    anchors.left: big.right
                    anchors.leftMargin: 12
                    anchors.right: buf.left
                    anchors.rightMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 3
                    Text {
                        width: parent.width
                        text: win.current ? win.current.n : ""
                        elide: Text.ElideRight
                        color: Theme.fg
                        font.family: Theme.font
                        font.pixelSize: Theme.fontSize + 1
                        font.bold: true
                    }
                    Text {
                        width: parent.width
                        visible: win.current !== null && win.section.id !== "fancy"
                        text: {
                            var c = win.current
                            if (!c || c.s === undefined || !Chars.sets[c.s]) return ""
                            var st = Chars.sets[c.s]
                            return (st.id === "kao" ? "" : Chars.hex(Chars.glyph(c, win.tone)) + "   ")
                                + st.label.toLowerCase() + " > " + st.groups[c.g].toLowerCase()
                        }
                        elide: Text.ElideRight
                        color: Theme.accent
                        font.family: Theme.font
                        font.pixelSize: Theme.fontSize - 1
                    }
                    Text {
                        width: parent.width
                        visible: text !== ""
                        text: win.current && win.current.k && win.section.id !== "kao" ? win.current.k : ""
                        elide: Text.ElideRight
                        color: Theme.dim
                        font.family: Theme.font
                        font.pixelSize: Theme.fontSize - 2
                    }
                }
                Row {   // collected with ctrl+enter / right click
                    id: buf
                    anchors.right: parent.right
                    anchors.rightMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 8
                    visible: win.buffer !== ""
                    width: visible ? implicitWidth : 0
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: Theme.iBuffer
                        color: Theme.accent
                        font.family: Theme.font
                        font.pixelSize: Theme.fontSize + 2
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        width: Math.min(implicitWidth, 220)
                        text: win.buffer
                        elide: Text.ElideLeft
                        color: Theme.fg
                        font.family: Theme.font
                        font.pixelSize: Theme.fontSize + 4
                    }
                }
            }

            Text {
                Layout.fillWidth: true
                text: "enter copy   " + (Chars.hasWtype ? "shift+enter type   " : "") + "ctrl+enter collect   alt+enter code   "
                    + "tab section   ctrl+arrows group   esc close"
                elide: Text.ElideRight
                color: Theme.dim
                font.family: Theme.font
                font.pixelSize: Theme.fontSize - 2
            }
        }
    }
}
