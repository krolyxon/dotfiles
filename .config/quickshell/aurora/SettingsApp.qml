import QtQuick
import QtQuick.Layouts
import Quickshell

// The settings app: a normal Hyprland window (class org.quickshell, title "aurora settings"), opened maximized by a
// window rule. glyph's prefs layout: the sections as a column of Doto words (the selected one large with the live dot),
// the page on the right under a caption, key hints at the bottom. One Loader, so only the shown section runs.
// Tab / Shift+Tab, Up/Down (outside text fields) or Ctrl+J/K = sections, Esc closes.
// Ctrl+F (or the search button) searches every setting (SetIndex): the results replace the page, Enter / click opens
// the section, scrolls to the row and flashes it.
// Opened with the `settings [section]` IPC. After glyph-rice (github.com/Nebelung-cloud/glyph-rice, GPL-3.0), prefs/Prefs.qml.
FloatingWindow {
    id: win
    property bool opened: false
    property string section: "network"
    signal closeRequested()
    signal sectionRequested(string name)
    signal overlayRequested(string name)

    visible: opened
    title: "aurora settings"
    implicitWidth: 1600
    implicitHeight: 900
    color: Theme.bg
    // closed by the compositor (killactive): keep shell state in sync
    onVisibleChanged: if (!visible && opened) closeRequested()
    onOpenedChanged: if (!opened) stopSearch()
    onSectionChanged: if (searching) stopSearch()      // switched from outside (IPC, Tab)

    readonly property var sections: SetIndex.sections
    readonly property int index: {
        for (var i = 0; i < sections.length; i++) if (sections[i].id === section) return i
        return 0
    }
    function cycle(d) { sectionRequested(sections[(index + d + sections.length) % sections.length].id) }
    // typing in a field: arrows belong to it
    function inText() { var a = win.activeFocusItem; return a !== null && a.cursorPosition !== undefined }

    // ---- search ----
    property bool searching: false
    property string query: ""
    property int pick: 0
    // the matches, then always "keybinds matching ..." (SetKeys has its own filter)
    readonly property var results: {
        var q = query.trim()
        if (!searching || q === "") return []
        return SetIndex.search(q).concat([{ kind: "keys", section: "keybinds", word: "keys", group: "",
                                            label: "keybinds matching “" + q + "”", hint: "filter the hyprland binds", query: q }])
    }
    readonly property var hitSections: {
        var h = {}
        for (var i = 0; i < results.length; i++) if (results[i].kind !== "keys") h[results[i].section] = true
        return h
    }
    onPickChanged: list.positionViewAtIndex(pick, ListView.Contain)

    function startSearch() {
        if (searching) searchInput.selectAll()
        searching = true
        searchInput.forceActiveFocus()
    }
    function stopSearch() {
        if (!searching) return
        searching = false
        searchInput.text = ""
        root.forceActiveFocus()
    }
    function crumb(e) {
        if (e.kind === "section") return "section"
        return e.word + (e.kind === "row" && e.group !== "" ? " · " + e.group : "")
    }

    // ---- landing on a result: open its section, find the row, scroll to it, flash it ----
    property var landing: null
    property int landTries: 0
    property Item hlTarget: null       // the flashed row (nulled when the page goes away)
    property Item hlFlick: null        // the Flickable it scrolls in, if any
    function go(e) {
        stopSearch()
        hlTarget = null
        landing = e
        landTries = 0
        if (e.section !== section) sectionRequested(e.section)
        landTimer.restart()
    }
    // the page's items in document order: past the group's SectionLabel, the first one with this label
    function findRow(e) {
        var hit = null, header = null, past = e.group === ""
        function walk(it) {
            var kids = it.children
            for (var i = 0; i < kids.length && !hit; i++) {
                var c = kids[i]
                if (e.group !== "" && c.actionClicked !== undefined && c.text === e.group) {
                    past = true
                    header = c
                    if (e.kind === "group") { hit = c; return }
                } else if (past && e.kind === "row" && c.label === e.label) {
                    hit = c
                    return
                }
                walk(c)
            }
        }
        if (loader.item) walk(loader.item)
        return { hit: hit, header: header }
    }
    function land() {
        var e = landing
        if (!e || !loader.item) { landTimer.stop(); landing = null; return }
        var top = e.kind === "section" || e.kind === "keys" || e.group === "" && e.kind === "group"
        var f = top ? { hit: null, header: null } : findRow(e)
        if (!top && !f.hit && ++landTries < 16) return     // rows from async data (monitors) may come late
        landTimer.stop()
        landing = null
        if (e.kind === "keys") loader.item.query = e.query
        if (!top && !f.hit) console.warn("settings search: no row for", e.section, "/", e.group, "/", e.label)
        // a hidden row (master-only knobs under dwindle...) -> its group's header
        var t = f.hit && f.hit.visible ? f.hit : f.header && f.header.visible ? f.header : null
        scrollTo(t)
        if (t) { hlTarget = t; flashAnim.restart() }
    }
    // t's row ~30% from the top of its Flickable; null = the top of the page
    function scrollTo(t) {
        var fl = null
        if (!t) fl = loader.item && loader.item.contentY !== undefined ? loader.item : null
        for (var p = t ? t.parent : null; p && p !== loader; p = p.parent)
            if (p.contentY !== undefined && p.contentHeight !== undefined) { fl = p; break }
        hlFlick = fl
        if (!fl) return
        var y = t ? t.mapToItem(fl.contentItem, 0, 0).y - fl.height * 0.3 : 0
        scrollAnim.stop()
        scrollAnim.target = fl
        scrollAnim.to = Math.max(0, Math.min(y, fl.contentHeight - fl.height))
        scrollAnim.start()
    }

    Item {
        id: root
        anchors.fill: parent
        focus: true
        Keys.onPressed: e => {
            var ctrl = e.modifiers & Qt.ControlModifier
            if (e.key === Qt.Key_Escape) { if (win.searching) win.stopSearch(); else win.closeRequested(); e.accepted = true }
            else if (ctrl && e.key === Qt.Key_F) { win.startSearch(); e.accepted = true }
            else if (e.key === Qt.Key_Tab || (ctrl && e.key === Qt.Key_J)) { win.cycle(1); e.accepted = true }
            else if (e.key === Qt.Key_Backtab || (ctrl && e.key === Qt.Key_K)) { win.cycle(-1); e.accepted = true }
        }
        // a click outside the page drops the focus out of text fields (arrows switch sections again)
        MouseArea { anchors.fill: parent; onClicked: root.forceActiveFocus() }

        Timer { id: landTimer; interval: 60; repeat: true; onTriggered: win.land() }
        NumberAnimation {
            id: scrollAnim
            property: "contentY"
            duration: Theme.t
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Theme.glide
        }
        SequentialAnimation {
            id: flashAnim
            NumberAnimation { target: flash; property: "opacity"; from: 0; to: 1; duration: Theme.t / 2 }
            PauseAnimation { duration: 1400 }
            NumberAnimation { target: flash; property: "opacity"; to: 0; duration: Theme.motion ? 800 : 0 }
            ScriptAction { script: win.hlTarget = null }
        }

        Item {
            id: stage
            anchors.fill: parent
            Keys.forwardTo: [root]

            // ---- sections ----
            Column {
                id: words
                x: Math.round(Math.min(150, win.width * 0.07))
                anchors.verticalCenter: parent.verticalCenter
                spacing: 12
                Repeater {
                    model: win.sections
                    Row {
                        id: w
                        required property var modelData
                        required property int index
                        readonly property bool on: win.index === index
                        spacing: 20
                        // while searching, sections without a match fade
                        opacity: !win.searching || win.query.trim() === "" || win.hitSections[modelData.id] ? 1 : 0.3
                        Behavior on opacity { enabled: Theme.motion; NumberAnimation { duration: Theme.t } }
                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: w.on
                            width: 20
                            height: 20
                            radius: 10
                            color: Theme.live
                        }
                        Num {
                            text: w.modelData.word.toUpperCase()
                            font.pixelSize: w.on ? 76 : 32
                            color: w.on ? Theme.fg : wm.hovered ? Theme.grey : Theme.mute
                            Behavior on font.pixelSize {
                                enabled: Theme.motion
                                NumberAnimation { duration: Theme.t; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.glide }
                            }
                            Behavior on color { enabled: Theme.motion; ColorAnimation { duration: Theme.t } }
                        }
                        HoverHandler { id: wm; cursorShape: Qt.PointingHandCursor }
                        TapHandler { onTapped: { win.stopSearch(); win.sectionRequested(w.modelData.id); root.forceActiveFocus() } }
                    }
                }
            }

            // ---- the page ----
            Item {
                id: pageBox
                x: Math.max(words.x + 560, Math.round(win.width * 0.42))
                y: 80
                width: Math.min(900, win.width - x - 80)
                height: parent.height - y - 110

                // the caption + search button, or the search pill
                Item {
                    id: head
                    width: parent.width
                    height: 52
                    Lb {
                        x: 18
                        anchors.verticalCenter: parent.verticalCenter
                        visible: !win.searching
                        text: win.sections[win.index].caption
                    }
                    IconBtn {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        visible: !win.searching
                        icon: Theme.iSearch
                        label: "search"
                        onClicked: win.startSearch()
                    }
                    Rectangle {
                        anchors.fill: parent
                        visible: win.searching
                        radius: height / 2
                        color: Theme.s2
                        Icon {
                            id: lens
                            x: 20
                            anchors.verticalCenter: parent.verticalCenter
                            text: Theme.iSearch
                            color: Theme.grey
                            font.pixelSize: 20
                        }
                        TextInput {
                            id: searchInput
                            anchors.left: lens.right
                            anchors.leftMargin: 14
                            anchors.right: found.left
                            anchors.rightMargin: 12
                            anchors.verticalCenter: parent.verticalCenter
                            font.family: Theme.ui
                            font.pixelSize: 18
                            color: Theme.fg
                            selectionColor: Theme.fill
                            selectedTextColor: Theme.fillFg
                            clip: true
                            cursorDelegate: Rectangle {
                                width: 2
                                color: Theme.live
                                visible: searchInput.activeFocus
                                Timer { running: searchInput.activeFocus; interval: 500; repeat: true; onTriggered: parent.opacity = 1 - parent.opacity }
                            }
                            Text {
                                visible: !searchInput.text
                                text: "search settings"
                                font: searchInput.font
                                color: Theme.mute
                            }
                            onTextChanged: { win.query = text; win.pick = 0 }
                            // handled here, so the window's Tab / Ctrl+J/K / Esc don't fire
                            Keys.onPressed: e => {
                                var ctrl = e.modifiers & Qt.ControlModifier, n = win.results.length
                                if (e.key === Qt.Key_Escape) win.stopSearch()
                                else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) { if (n) win.go(win.results[win.pick]) }
                                else if (e.key === Qt.Key_Down || e.key === Qt.Key_Tab || (ctrl && e.key === Qt.Key_J)) { if (n) win.pick = (win.pick + 1) % n }
                                else if (e.key === Qt.Key_Up || e.key === Qt.Key_Backtab || (ctrl && e.key === Qt.Key_K)) { if (n) win.pick = (win.pick + n - 1) % n }
                                else if (ctrl && e.key === Qt.Key_F) selectAll()
                                else return
                                e.accepted = true
                            }
                        }
                        Lb {
                            id: found
                            anchors.right: parent.right
                            anchors.rightMargin: 22
                            anchors.verticalCenter: parent.verticalCenter
                            text: win.results.length ? (win.results.length - 1) + " found" : ""
                        }
                    }
                }

                Item {
                    anchors.top: head.bottom
                    anchors.topMargin: 16
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom

                    // the found row's flash, behind the page (rows have no background of their own)
                    Item {
                        id: flashBox
                        anchors.fill: parent
                        clip: true
                        Rectangle {
                            id: flash
                            // re-mapped while the page scrolls or relayouts
                            readonly property rect r: {
                                var t = win.hlTarget
                                if (!t) return Qt.rect(0, 0, 0, 0)
                                void ((win.hlFlick ? win.hlFlick.contentY : 0) + t.y + t.width + t.height + flashBox.width)
                                return t.mapToItem(flashBox, 0, 0, t.width, t.height)
                            }
                            readonly property real pad: 4
                            visible: win.hlTarget !== null && !win.searching
                            opacity: 0
                            width: parent.width
                            y: r.y - pad
                            height: r.height + 2 * pad
                            radius: height / 2
                            color: Theme.fade(Theme.fill, 0.2)
                        }
                    }

                    Loader {
                        id: loader
                        anchors.fill: parent
                        visible: !win.searching             // kept loaded: Esc returns to the same spot
                        active: win.opened
                        sourceComponent: {
                            switch (win.section) {
                            case "bluetooth":  return btC
                            case "sound":      return soundC
                            case "appearance": return appearanceC
                            case "shell":      return shellC
                            case "windows":    return windowsC
                            case "input":      return inputC
                            case "keybinds":   return keysC
                            case "display":    return displayC
                            case "power":      return powerC
                            case "about":      return aboutC
                            default:           return netC
                            }
                        }
                    }

                    // ---- search results ----
                    Lb {
                        x: 18
                        visible: win.searching && win.query.trim() === ""
                        text: "type a setting, a word or a section"
                    }
                    ListView {
                        id: list
                        anchors.fill: parent
                        visible: win.searching
                        clip: true
                        spacing: 2
                        boundsBehavior: Flickable.StopAtBounds
                        model: win.results
                        header: Item {
                            width: list.width
                            height: win.results.length === 1 ? 44 : 0
                            Lb {
                                x: 18
                                anchors.verticalCenter: parent.verticalCenter
                                visible: parent.height > 0
                                text: "no setting matches"
                            }
                        }
                        delegate: Rectangle {
                            id: r
                            required property var modelData
                            required property int index
                            readonly property bool on: win.pick === index
                            width: ListView.view.width
                            height: Math.max(56, txt.implicitHeight + 20)
                            radius: 28
                            color: on || rm.containsMouse ? Theme.s2 : "transparent"
                            Rectangle {
                                x: 20
                                anchors.verticalCenter: parent.verticalCenter
                                visible: r.on
                                width: 10
                                height: 10
                                radius: 5
                                color: Theme.live
                            }
                            ColumnLayout {
                                id: txt
                                anchors.left: parent.left
                                anchors.leftMargin: 44
                                anchors.right: parent.right
                                anchors.rightMargin: 18
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 3
                                Text {
                                    Layout.fillWidth: true
                                    text: r.modelData.label
                                    color: Theme.fg
                                    elide: Text.ElideRight
                                    font.family: Theme.ui
                                    font.pixelSize: 15
                                }
                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 12
                                    Lb { text: win.crumb(r.modelData); px: 10 }
                                    Text {
                                        Layout.fillWidth: true
                                        visible: r.modelData.hint !== ""
                                        text: r.modelData.hint
                                        color: Theme.fgDim
                                        elide: Text.ElideRight
                                        font.family: Theme.ui
                                        font.pixelSize: 13
                                    }
                                }
                            }
                            MouseArea {
                                id: rm
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: win.go(r.modelData)
                            }
                        }
                    }
                }
            }

            Row {
                x: words.x
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 50
                spacing: 34
                Repeater {
                    model: win.searching ? ["↑↓ result", "↵ open", "esc back"] : ["ctrl+f search", "tab · ↑↓ section", "esc close"]
                    Lb { required property string modelData; text: modelData }
                }
            }
        }
        // ↑↓ switch sections unless a text field has the keyboard
        Keys.onUpPressed: e => { if (win.inText()) { e.accepted = false; return } win.cycle(-1) }
        Keys.onDownPressed: e => { if (win.inText()) { e.accepted = false; return } win.cycle(1) }
    }

    Component { id: netC; NetPage { active: true } }
    Component { id: btC; BtPage { active: true } }
    Component { id: soundC; AudioPage {} }
    Component { id: appearanceC; SetAppearance { onOverlayRequested: name => win.overlayRequested(name) } }
    Component { id: shellC; SetShell {} }
    Component { id: windowsC; SetWindows {} }
    Component { id: inputC; SetInput {} }
    Component { id: keysC; SetKeys {} }
    Component { id: displayC; SetDisplay {} }
    Component { id: powerC; SetPower {} }
    Component { id: aboutC; SetAbout {} }
}
