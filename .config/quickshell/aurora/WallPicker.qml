import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland

// Wallpaper picker: the whole screen previews the selected wallpaper in the current look (no matugen until you apply),
// a card at the bottom holds folder chips, the look (mono dots / colour dots / photo), the filter and the thumbnails.
// Vim-style: the grid has the keyboard (hjkl/arrows move, g/G first/last, ctrl+d/u page), `/` searches (enter keeps the
// filter, esc clears it), `v` cycles the look, Tab / Shift+Tab the folders. Enter / double-click applies (stays open to
// try a few), Esc / q or a click on the preview closes. After glyph-rice (github.com/Nebelung-cloud/glyph-rice, GPL-3.0), wall/Walls.qml.
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
    WlrLayershell.namespace: "aurora-wallpaper"
    WlrLayershell.keyboardFocus: opened ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    property bool pendingSel: false      // just opened: select the current wallpaper once the folder is listed
    onOpenedChanged: {
        if (!opened) { previewPath = ""; return }
        filter.text = ""
        pendingSel = true
        Wall.refresh()
        grid.forceActiveFocus()
        selT.restart()
    }
    function selectCurrent() {
        if (!pendingSel || Wall.loading || !shown.length) return
        pendingSel = false
        var i = shown.indexOf(Wall.current)
        if (i >= 0) { grid.currentIndex = i; grid.positionViewAtIndex(i, GridView.Center) }
    }

    // search mode = the filter box has the keyboard (entered with `/` or by clicking it)
    readonly property bool searching: filter.activeFocus
    function search() { filter.forceActiveFocus() }
    function endSearch(clear) {
        if (clear) filter.text = ""
        grid.forceActiveFocus()
    }
    function applyCurrent() { if (grid.currentIndex >= 0 && grid.currentIndex < shown.length) Wall.apply(shown[grid.currentIndex]) }
    function page(d) {
        grid.currentIndex = Math.max(0, Math.min(shown.length - 1, grid.currentIndex + d * grid.perPage))
    }
    readonly property var looks: ["dots", "colour", "photo"]
    function cycleLook() { Settings.wallLook = looks[(looks.indexOf(Settings.wallLook) + 1) % looks.length] }

    readonly property var shown: {
        var q = filter.text.toLowerCase(), out = [], l = Wall.files
        for (var i = 0; i < l.length; i++)
            if (q === "" || l[i].substring(l[i].lastIndexOf("/") + 1).toLowerCase().indexOf(q) >= 0) out.push(l[i])
        return out
    }
    // after the grid has taken the new model (replacing it resets its currentIndex to 0)
    Timer { id: selT; interval: 60; onTriggered: win.selectCurrent() }
    onShownChanged: if (pendingSel) selT.restart()
    Connections {
        target: Wall
        function onLoadingChanged() { if (win.pendingSel) selT.restart() }
    }
    readonly property var chips: [""].concat(Wall.folders)

    function cycleFolder(d) {
        var i = chips.indexOf(Wall.folder)
        Wall.listFolder(chips[(i + d + chips.length) % chips.length])
    }
    function name(p) { return p.substring(p.lastIndexOf("/") + 1) }

    // the preview follows the selection after a short pause (flipping fast with hjkl doesn't load every image)
    property string previewPath: ""
    readonly property string selected: opened && grid.currentIndex >= 0 && grid.currentIndex < shown.length ? shown[grid.currentIndex] : ""
    onSelectedChanged: previewT.restart()
    Timer { id: previewT; interval: 220; onTriggered: win.previewPath = win.selected || Wall.current }

    // ---- the preview, full screen ----
    Rectangle {
        anchors.fill: parent
        color: Theme.bg
        opacity: win.t
        WallView {
            anchors.fill: parent
            path: win.previewPath !== "" ? win.previewPath : Wall.current
        }
        MouseArea { anchors.fill: parent; onClicked: win.closeRequested() }
        Lb {
            x: 40
            y: 32
            px: 11
            color: Theme.fg
            text: "preview · " + win.name(win.previewPath !== "" ? win.previewPath : Wall.current)
                  + (win.previewPath !== "" && win.previewPath !== Wall.current ? " · ↵ apply" : " · on now")
        }
    }

    // ---- the card ----
    Rectangle {
        id: card
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 24 - 24 * (1 - win.t)
        width: Math.min(parent.width - 48, 1480)
        height: Math.round(parent.height * 0.46)
        opacity: win.t
        radius: 40
        color: Theme.fade(Theme.s1, Theme.panelAlpha)
        border.width: 1
        border.color: Theme.s2
        MouseArea { anchors.fill: parent }   // clicks on the card don't close

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 24
            spacing: 14

            RowLayout {
                Layout.fillWidth: true
                spacing: 10
                Flow {
                    Layout.fillWidth: true
                    spacing: 2
                    Repeater {
                        model: win.chips
                        delegate: Chip {
                            required property var modelData
                            text: modelData === "" ? "all" : modelData
                            selected: Wall.folder === modelData
                            onClicked: Wall.listFolder(modelData)
                        }
                    }
                }
                Segmented {
                    Layout.preferredWidth: 330
                    implicitHeight: 44
                    options: [{ value: "dots", label: "mono" }, { value: "colour", label: "colour" }, { value: "photo", label: "photo" }]
                    value: Settings.wallLook
                    onPicked: v => Settings.wallLook = v
                }
                IconBtn { implicitHeight: 44; icon: Theme.iShuffle; label: "random"; onClicked: Wall.random() }
                IconBtn { implicitHeight: 44; icon: Theme.iClose; onClicked: win.closeRequested() }
            }

            // filter: a pill with the live caret
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 48
                radius: height / 2
                color: Theme.s2
                border.width: win.searching ? 1 : 0
                border.color: Theme.fill
                Icon {
                    id: lens
                    x: 20
                    anchors.verticalCenter: parent.verticalCenter
                    text: Theme.iSearch
                    color: win.searching ? Theme.fg : Theme.grey
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
                    font.pixelSize: 16
                    clip: true
                    cursorDelegate: Rectangle {
                        width: 2
                        color: Theme.live
                        visible: filter.activeFocus
                        Timer { running: filter.activeFocus; interval: 500; repeat: true; onTriggered: parent.opacity = 1 - parent.opacity }
                    }
                    onTextChanged: grid.currentIndex = 0
                    // like vim's `/`: enter keeps the filter and goes back to the grid, esc drops it
                    Keys.onEscapePressed: win.endSearch(true)
                    Keys.onReturnPressed: win.endSearch(false)
                    Keys.onEnterPressed: win.endSearch(false)
                    Keys.onUpPressed: grid.moveCurrentIndexUp()
                    Keys.onDownPressed: grid.moveCurrentIndexDown()
                    Keys.onTabPressed: win.cycleFolder(1)
                    Keys.onBacktabPressed: win.cycleFolder(-1)
                    // ctrl+hjkl moves through the results without leaving the search
                    Keys.onPressed: event => {
                        if (!(event.modifiers & Qt.ControlModifier)) return
                        event.accepted = true
                        if (event.key === Qt.Key_H) grid.moveCurrentIndexLeft()
                        else if (event.key === Qt.Key_J) grid.moveCurrentIndexDown()
                        else if (event.key === Qt.Key_K) grid.moveCurrentIndexUp()
                        else if (event.key === Qt.Key_L) grid.moveCurrentIndexRight()
                        else event.accepted = false
                    }
                    Text {
                        visible: filter.text === "" && !win.searching
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Press / to search wallpapers"
                        font: filter.font
                        color: Theme.mute
                    }
                }
                Lb {
                    id: count
                    anchors.right: parent.right
                    anchors.rightMargin: 22
                    anchors.verticalCenter: parent.verticalCenter
                    text: Wall.loading ? "…" : win.shown.length + " / " + Wall.files.length
                }
            }

            GridView {
                id: grid
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                readonly property int cols: Math.max(1, Math.floor(width / 230))
                readonly property int perPage: cols * Math.max(1, Math.floor(height / cellHeight))
                cellWidth: Math.floor(width / cols)
                cellHeight: Math.round(cellWidth * 9 / 16) + 30
                model: win.shown
                currentIndex: 0
                boundsBehavior: Flickable.StopAtBounds
                highlightMoveDuration: 0
                cacheBuffer: cellHeight * 2

                // normal mode (arrows are handled by GridView itself)
                Keys.onTabPressed: win.cycleFolder(1)
                Keys.onBacktabPressed: win.cycleFolder(-1)
                Keys.onPressed: event => {
                    var ctrl = event.modifiers & Qt.ControlModifier
                    event.accepted = true
                    if (event.key === Qt.Key_Escape) {
                        if (filter.text !== "") filter.text = ""     // first esc drops an active filter
                        else win.closeRequested()
                    }
                    else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) win.applyCurrent()
                    else if (event.key === Qt.Key_PageDown || (ctrl && event.key === Qt.Key_D)) win.page(1)
                    else if (event.key === Qt.Key_PageUp || (ctrl && event.key === Qt.Key_U)) win.page(-1)
                    else if (ctrl) event.accepted = false
                    else if (event.text === "/") win.search()
                    else if (event.text === "h") grid.moveCurrentIndexLeft()
                    else if (event.text === "j") grid.moveCurrentIndexDown()
                    else if (event.text === "k") grid.moveCurrentIndexUp()
                    else if (event.text === "l") grid.moveCurrentIndexRight()
                    else if (event.text === "g") grid.currentIndex = 0
                    else if (event.text === "G") grid.currentIndex = win.shown.length - 1
                    else if (event.text === "v") win.cycleLook()
                    else if (event.text === "q") win.closeRequested()
                    else event.accepted = false
                }

                delegate: Item {
                    id: cell
                    required property var modelData
                    required property int index
                    readonly property string hash: Qt.md5(modelData)
                    readonly property bool isCurrent: Wall.current === modelData
                    readonly property bool selected: grid.currentIndex === index
                    width: grid.cellWidth
                    height: grid.cellHeight

                    Rectangle {
                        id: frame
                        x: 6
                        y: 6
                        width: parent.width - 12
                        height: parent.height - 36
                        radius: 22
                        color: Theme.s2
                        border.width: cell.selected ? 2 : 0
                        border.color: Theme.fill
                        Image {
                            id: img
                            anchors.fill: parent
                            anchors.margins: cell.selected ? 5 : 0
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            cache: false
                            sourceSize.width: 320
                            sourceSize.height: 180
                            source: Wall.ready[cell.hash] ? "file://" + Wall.thumbDir + "/" + cell.hash + ".jpg" : ""
                            layer.enabled: true
                            layer.effect: MultiEffect { maskEnabled: true; maskSource: mask }
                        }
                        Rectangle {
                            id: mask
                            width: img.width
                            height: img.height
                            radius: cell.selected ? 17 : 22
                            visible: false
                            layer.enabled: true
                        }
                        Icon {
                            anchors.centerIn: parent
                            visible: img.status !== Image.Ready
                            text: Theme.iImage
                            color: Theme.mute
                            font.pixelSize: 22
                        }
                    }
                    Row {
                        anchors.left: frame.left
                        anchors.leftMargin: 8
                        anchors.right: frame.right
                        anchors.top: frame.bottom
                        anchors.topMargin: 8
                        spacing: 8
                        Rectangle {
                            visible: cell.isCurrent
                            anchors.verticalCenter: parent.verticalCenter
                            width: 8
                            height: 8
                            radius: 4
                            color: Theme.live
                        }
                        Lb {
                            width: parent.width - (cell.isCurrent ? 16 : 0)
                            elide: Text.ElideMiddle
                            px: 10
                            text: win.name(cell.modelData)
                            color: cell.selected ? Theme.fg : Theme.grey
                        }
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: { grid.currentIndex = cell.index; grid.forceActiveFocus() }
                        onDoubleClicked: Wall.apply(cell.modelData)
                    }
                }
            }

            Row {
                spacing: 30
                Repeater {
                    model: win.searching ? ["↵ done", "esc clear", "↑↓ move"]
                                         : ["hjkl move", "/ search", "↵ apply", "v look", "tab folder", "g/G first/last", "esc close"]
                    Lb { required property string modelData; text: modelData; px: 10 }
                }
            }
        }
    }
}
