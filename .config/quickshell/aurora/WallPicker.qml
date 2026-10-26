import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland

// Wallpaper picker: folder chips, filter, thumbnail grid. Vim-style: the grid has the keyboard
// (hjkl/arrows move, g/G first/last, ctrl+d/u page), `/` starts searching (enter keeps the filter,
// esc clears it). Enter / double-click applies (stays open so you can try a few), Esc / q or click
// outside closes. Tab / Shift+Tab cycles folders.
PanelWindow {
    id: win
    property bool opened: false
    signal closeRequested()

    visible: opened
    implicitWidth: screen ? Math.round(screen.width * 0.7) : 1200
    implicitHeight: screen ? Math.round(screen.height * 0.7) : 700
    exclusiveZone: 0
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "aurora-wallpaper"
    WlrLayershell.keyboardFocus: opened ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    HyprlandFocusGrab {
        windows: [win]
        active: win.opened
        onCleared: win.closeRequested()
    }

    onOpenedChanged: {
        if (!opened) return
        filter.text = ""
        Wall.refresh()
        grid.forceActiveFocus()
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

    readonly property var shown: {
        var q = filter.text.toLowerCase(), out = [], l = Wall.files
        for (var i = 0; i < l.length; i++)
            if (q === "" || l[i].substring(l[i].lastIndexOf("/") + 1).toLowerCase().indexOf(q) >= 0) out.push(l[i])
        return out
    }
    readonly property var chips: [""].concat(Wall.folders)

    function cycleFolder(d) {
        var i = chips.indexOf(Wall.folder)
        Wall.listFolder(chips[(i + d + chips.length) % chips.length])
    }
    function name(p) { return p.substring(p.lastIndexOf("/") + 1) }

    Rectangle {
        anchors.fill: parent
        color: Theme.bgA
        border.width: 2
        border.color: Theme.accent

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 10

            // folder chips
            Flow {
                Layout.fillWidth: true
                spacing: 4
                Repeater {
                    model: win.chips
                    delegate: Rectangle {
                        id: chip
                        required property var modelData
                        readonly property bool current: Wall.folder === modelData
                        width: cl.implicitWidth + 18
                        height: 24
                        color: current ? Theme.accent : (cm.containsMouse ? Theme.surfaceHi : "transparent")
                        border.width: 1
                        border.color: current ? Theme.accent : Theme.line
                        Text {
                            id: cl
                            anchors.centerIn: parent
                            text: chip.modelData === "" ? "all" : chip.modelData
                            color: chip.current ? Theme.bg : Theme.fg
                            font.family: Theme.font
                            font.pixelSize: Theme.fontSize - 1
                            font.bold: chip.current
                        }
                        MouseArea {
                            id: cm
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Wall.listFolder(chip.modelData)
                        }
                    }
                }
            }

            // filter + actions
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
                        text: win.searching ? "/" : Theme.iSearch
                        color: win.searching ? Theme.accent : Theme.dim
                        font.family: Theme.font
                        font.pixelSize: Theme.fontSize
                        font.bold: win.searching
                    }
                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: 32
                        anchors.verticalCenter: parent.verticalCenter
                        visible: filter.text === "" && !win.searching
                        text: "press / to search"
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
                    }
                }
                Text {
                    text: Wall.loading ? "..." : win.shown.length + " / " + Wall.files.length
                    color: Theme.dim
                    font.family: Theme.font
                    font.pixelSize: Theme.fontSize - 1
                }
                IconBtn { icon: Theme.iShuffle; label: "random"; onClicked: Wall.random() }
                IconBtn { icon: Theme.iClose; onClicked: win.closeRequested() }
            }

            GridView {
                id: grid
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                readonly property int cols: Math.max(1, Math.floor(width / 240))
                readonly property int perPage: cols * Math.max(1, Math.floor(height / cellHeight))
                cellWidth: Math.floor(width / cols)
                cellHeight: Math.round(cellWidth * 9 / 16) + 22
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
                        anchors.fill: parent
                        anchors.margins: 4
                        color: Theme.surface
                        border.width: cell.selected || cell.isCurrent ? 2 : 1
                        border.color: cell.selected ? Theme.fg : (cell.isCurrent ? Theme.accent : Theme.line)

                        Image {
                            id: img
                            anchors.fill: parent
                            anchors.margins: 2
                            anchors.bottomMargin: 20
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            cache: false
                            sourceSize.width: 320
                            sourceSize.height: 180
                            source: Wall.ready[cell.hash] ? "file://" + Wall.thumbDir + "/" + cell.hash + ".jpg" : ""
                        }
                        Text {
                            anchors.centerIn: img
                            visible: img.status !== Image.Ready
                            text: Theme.iImage
                            color: Theme.dim
                            font.family: Theme.font
                            font.pixelSize: 22
                        }
                        Text {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            anchors.margins: 4
                            height: 14
                            text: (cell.isCurrent ? Theme.iCheck + " " : "") + win.name(cell.modelData)
                            elide: Text.ElideMiddle
                            color: cell.isCurrent ? Theme.accent : Theme.dim
                            font.family: Theme.font
                            font.pixelSize: Theme.fontSize - 2
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

            Text {
                Layout.fillWidth: true
                text: (win.searching ? "-- SEARCH --   enter done   esc clear   ↑↓ move   "
                                     : "hjkl move   / search   enter apply   tab folder   g/G first/last   esc close   ")
                      + Theme.iImage + " " + win.name(Wall.current)
                elide: Text.ElideRight
                color: Theme.dim
                font.family: Theme.font
                font.pixelSize: Theme.fontSize - 2
            }
        }
    }
}
