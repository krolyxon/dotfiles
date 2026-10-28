import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland

// Clipboard history (cliphist): a card over the dimmed screen. Search pill with the live caret, filter chips
// (Tab cycles: all / text / links / images), the history as rows (type in a circle: text, link, code, the colour
// itself, the image as dots; a Doto number) and the selected entry in full on the right.
// Enter copies + closes, Delete removes, Esc or a click outside closes.
// After glyph-rice (github.com/Nebelung-cloud/glyph-rice, GPL-3.0), clip/Clip.qml.
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
    WlrLayershell.namespace: "aurora-clipboard"
    WlrLayershell.keyboardFocus: opened ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    onOpenedChanged: {
        if (!opened) return
        filter.text = ""
        kind = 0
        armed = false
        Clip.refresh()
        list.currentIndex = 0
        filter.forceActiveFocus()
    }

    property bool armed: false
    Timer { id: disarm; interval: 3000; onTriggered: win.armed = false }

    readonly property var kinds: ["all", "text", "links", "images"]
    property int kind: 0
    function typeOf(e) {
        if (e.image) return "image"
        var t = e.text.trim()
        if (/^(https?|ftp|file):\/\/\S+$/i.test(t) || /^www\.\S+$/i.test(t)) return "link"
        if (/^#([0-9a-f]{3}|[0-9a-f]{6}|[0-9a-f]{8})$/i.test(t) || /^rgba?\(/i.test(t)) return "colour"
        if (/[{};]|=>|^\s*(sudo|git|cd|ls|cat|echo|hyprctl|qs|pacman|paru|systemctl|python3?)\s/.test(t)) return "code"
        return "text"
    }
    readonly property var shown: {
        var q = filter.text.toLowerCase(), out = [], l = Clip.entries, k = kinds[kind]
        for (var i = 0; i < l.length; i++) {
            var ty = typeOf(l[i])
            if (k === "text" && (ty === "image" || ty === "link")) continue
            if (k === "links" && ty !== "link") continue
            if (k === "images" && ty !== "image") continue
            if (q === "" || l[i].text.toLowerCase().indexOf(q) >= 0) out.push(l[i])
        }
        return out
    }
    readonly property var cur: list.currentIndex >= 0 && list.currentIndex < shown.length ? shown[list.currentIndex] : null
    function pick(e) {
        if (!e) return
        Clip.copy(e.id)
        closeRequested()
    }
    function icon(ty) { return ty === "link" ? Theme.iLink : ty === "code" ? Theme.iCode : ty === "image" ? Theme.iImage : Theme.iText }

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
        width: Math.min(parent.width - 80, 1160)
        height: Math.min(parent.height - 160, 780)
        opacity: win.t
        radius: 44
        color: Qt.rgba(Theme.s1.r, Theme.s1.g, Theme.s1.b, Theme.panelAlpha)
        border.width: 1
        border.color: Theme.s2
        MouseArea { anchors.fill: parent }

        // ---- search ----
        Rectangle {
            id: search
            x: 34
            y: 30
            width: parent.width - 68
            height: 66
            radius: 33
            color: Theme.s2
            Icon { id: lens; x: 24; anchors.verticalCenter: parent.verticalCenter; text: Theme.iSearch; color: Theme.grey; font.pixelSize: 22 }
            TextInput {
                id: filter
                anchors.left: lens.right
                anchors.leftMargin: 16
                anchors.right: chips.left
                anchors.rightMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                font.family: Theme.ui
                font.pixelSize: 22
                color: Theme.fg
                selectionColor: Theme.fill
                selectedTextColor: Theme.fillFg
                clip: true
                cursorDelegate: Rectangle {
                    width: 2
                    color: Theme.live
                    visible: filter.activeFocus
                    Timer { running: filter.activeFocus; interval: 500; repeat: true; onTriggered: parent.opacity = 1 - parent.opacity }
                }
                Text {
                    visible: !filter.text
                    text: "Search clipboard"
                    font: filter.font
                    color: Theme.mute
                }
                onTextChanged: list.currentIndex = 0
                Keys.onEscapePressed: win.closeRequested()
                Keys.onReturnPressed: win.pick(win.cur)
                Keys.onEnterPressed: win.pick(win.cur)
                Keys.onUpPressed: list.decrementCurrentIndex()
                Keys.onDownPressed: list.incrementCurrentIndex()
                Keys.onTabPressed: { win.kind = (win.kind + 1) % win.kinds.length; list.currentIndex = 0 }
                Keys.onBacktabPressed: { win.kind = (win.kind + win.kinds.length - 1) % win.kinds.length; list.currentIndex = 0 }
                Keys.onPressed: event => {
                    if (event.key === Qt.Key_Delete && win.cur) {
                        Clip.remove(win.cur.id)
                        event.accepted = true
                    } else if (event.key === Qt.Key_PageDown) {
                        list.currentIndex = Math.min(win.shown.length - 1, list.currentIndex + 10); event.accepted = true
                    } else if (event.key === Qt.Key_PageUp) {
                        list.currentIndex = Math.max(0, list.currentIndex - 10); event.accepted = true
                    }
                }
            }
            Row {
                id: chips
                anchors.right: parent.right
                anchors.rightMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6
                Repeater {
                    model: win.kinds
                    Chip {
                        required property string modelData
                        required property int index
                        text: modelData
                        selected: win.kind === index
                        onClicked: { win.kind = index; list.currentIndex = 0; filter.forceActiveFocus() }
                    }
                }
            }
        }

        // ---- the history ----
        Row {
            id: head
            x: 40
            anchors.top: search.bottom
            anchors.topMargin: 22
            spacing: 14
            Num { anchors.baseline: hl.baseline; text: win.shown.length; font.pixelSize: 34 }
            Lb { id: hl; text: win.shown.length === 1 ? "entry" : "entries" }
        }
        Row {
            anchors.right: list.right
            anchors.verticalCenter: head.verticalCenter
            spacing: 8
            IconBtn {
                visible: Clip.entries.length > 0
                icon: Theme.iTrash
                label: win.armed ? "sure?" : "wipe all"
                active: win.armed
                onClicked: {
                    if (!win.armed) { win.armed = true; disarm.restart(); return }
                    win.armed = false
                    Clip.wipe()
                }
            }
        }

        ListView {
            id: list
            x: 34
            anchors.top: head.bottom
            anchors.topMargin: 18
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 34
            width: Math.round((parent.width - 68) * 0.48)
            clip: true
            model: win.shown
            spacing: 4
            boundsBehavior: Flickable.StopAtBounds
            highlightMoveDuration: 0

            delegate: Rectangle {
                id: row
                required property var modelData
                required property int index
                readonly property bool selected: list.currentIndex === index
                readonly property string ty: win.typeOf(modelData)
                readonly property bool hasImg: modelData.image && Clip.ready[modelData.id] === true
                width: list.width
                height: 66
                radius: 33
                color: selected ? Theme.fill : rm.containsMouse ? Theme.s2 : "transparent"

                MouseArea {
                    id: rm
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onEntered: list.currentIndex = row.index
                    onClicked: win.pick(row.modelData)
                }
                Rectangle {
                    id: ic
                    x: 8
                    anchors.verticalCenter: parent.verticalCenter
                    width: 50
                    height: 50
                    radius: 25
                    color: row.ty === "colour" ? row.modelData.text.trim() : row.selected ? Theme.fillFg : Theme.s2
                    Icon {
                        anchors.centerIn: parent
                        visible: row.ty !== "colour" && !thumb.visible
                        text: win.icon(row.ty)
                        font.pixelSize: 20
                        color: row.selected ? Theme.fill : Theme.fg
                    }
                    Image {
                        id: thumb
                        anchors.fill: parent
                        visible: row.hasImg && status === Image.Ready
                        source: row.hasImg ? "file://" + Clip.imageOf(row.modelData) : ""
                        fillMode: Image.PreserveAspectCrop
                        sourceSize: Qt.size(100, 100)
                        asynchronous: true
                        layer.enabled: true
                        layer.effect: DotMask { step: 3; circle: true }
                    }
                }
                Column {
                    anchors.left: ic.right
                    anchors.leftMargin: 14
                    anchors.right: num.left
                    anchors.rightMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    Text {
                        width: parent.width
                        elide: Text.ElideRight
                        maximumLineCount: 1
                        text: row.modelData.text.replace(/\s+/g, " ")
                        font.family: Theme.ui
                        font.pixelSize: 15
                        color: row.selected ? Theme.fillFg : Theme.fg
                    }
                    Lb { text: row.ty; px: 10; color: row.selected ? Theme.fillFg : Theme.grey }
                }
                Num {
                    id: num
                    anchors.right: parent.right
                    anchors.rightMargin: 22
                    anchors.verticalCenter: parent.verticalCenter
                    text: ("0" + (row.index + 1)).slice(-2)
                    font.pixelSize: 28
                    color: row.selected ? Theme.fillFg : Theme.mute
                }
            }
            Lb {
                visible: win.shown.length === 0
                anchors.centerIn: parent
                color: Theme.mute
                text: Clip.available ? (Clip.entries.length ? "no match" : "clipboard is empty") : "cliphist is not installed"
            }
        }

        // ---- the selected entry in full ----
        Rectangle {
            id: preview
            anchors.left: list.right
            anchors.leftMargin: 24
            anchors.right: parent.right
            anchors.rightMargin: 34
            anchors.top: search.bottom
            anchors.topMargin: 30
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 34
            radius: 30
            color: Theme.s2
            readonly property var e: win.cur
            readonly property string ty: e ? win.typeOf(e) : ""

            Lb {
                id: pl
                x: 30
                y: 28
                text: preview.e ? preview.ty + " · " + (list.currentIndex + 1) + " of " + win.shown.length : ""
            }
            Text {
                visible: preview.e !== null && preview.ty !== "image"
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: pl.bottom
                anchors.bottom: parent.bottom
                anchors.margins: 30
                wrapMode: Text.WrapAnywhere
                elide: Text.ElideRight
                textFormat: Text.PlainText
                text: preview.e ? preview.e.text : ""
                font.family: preview.ty === "code" ? Theme.mono : Theme.ui
                font.pixelSize: preview.ty === "code" ? 14 : 17
                color: preview.ty === "colour" ? preview.e.text.trim() : Theme.fg
            }
            Image {
                id: big
                visible: preview.ty === "image"
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: pl.bottom
                anchors.bottom: dims.top
                anchors.margins: 30
                fillMode: Image.PreserveAspectFit
                asynchronous: true
                sourceSize.width: 900
                source: preview.ty === "image" && Clip.ready[preview.e.id] ? "file://" + Clip.imageOf(preview.e) : ""
            }
            Row {
                id: dims
                visible: preview.ty === "image"
                x: 30
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 28
                spacing: 12
                Num { anchors.baseline: df.baseline; text: preview.e && preview.ty === "image" ? preview.e.text.split("  ")[1] || "" : ""; font.pixelSize: 40 }
                Lb { id: df; text: preview.e && preview.ty === "image" ? preview.e.fmt : "" }
            }
        }
    }

    Row {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: card.bottom
        anchors.topMargin: 28
        opacity: win.t
        spacing: 36
        Repeater {
            model: ["↑↓ select", "↵ copy", "tab filter", "del delete", "esc close"]
            Lb { required property string modelData; text: modelData }
        }
    }
}
