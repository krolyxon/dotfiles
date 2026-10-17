import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland

// Clipboard history: type to filter, Up/Down, Enter copies + closes, Delete removes, Esc closes.
PanelWindow {
    id: win
    property bool opened: false
    signal closeRequested()

    visible: opened
    implicitWidth: 620
    implicitHeight: 560
    exclusiveZone: 0
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "aurora-clipboard"
    WlrLayershell.keyboardFocus: opened ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    HyprlandFocusGrab {
        windows: [win]
        active: win.opened
        onCleared: win.closeRequested()
    }

    onOpenedChanged: {
        if (!opened) return
        filter.text = ""
        armed = false
        Clip.refresh()
        list.currentIndex = 0
        filter.forceActiveFocus()
    }

    property bool armed: false
    Timer { id: disarm; interval: 3000; onTriggered: win.armed = false }

    readonly property var shown: {
        var q = filter.text.toLowerCase(), out = [], l = Clip.entries
        for (var i = 0; i < l.length; i++)
            if (q === "" || l[i].text.toLowerCase().indexOf(q) >= 0) out.push(l[i])
        return out
    }
    function pick(e) {
        if (!e) return
        Clip.copy(e.id)
        closeRequested()
    }

    Rectangle {
        anchors.fill: parent
        color: Theme.bgA
        border.width: 2
        border.color: Theme.accent

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 10

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
                        text: Theme.iClipboard
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
                        onTextChanged: list.currentIndex = 0
                        Keys.onEscapePressed: win.closeRequested()
                        Keys.onReturnPressed: win.pick(win.shown[list.currentIndex])
                        Keys.onEnterPressed: win.pick(win.shown[list.currentIndex])
                        Keys.onUpPressed: list.decrementCurrentIndex()
                        Keys.onDownPressed: list.incrementCurrentIndex()
                        Keys.onPressed: event => {
                            if (event.key === Qt.Key_Delete && list.currentIndex >= 0 && win.shown.length) {
                                Clip.remove(win.shown[list.currentIndex].id)
                                event.accepted = true
                            } else if (event.key === Qt.Key_PageDown) {
                                list.currentIndex = Math.min(win.shown.length - 1, list.currentIndex + 10); event.accepted = true
                            } else if (event.key === Qt.Key_PageUp) {
                                list.currentIndex = Math.max(0, list.currentIndex - 10); event.accepted = true
                            }
                        }
                    }
                }
                Text {
                    text: win.shown.length
                    color: Theme.dim
                    font.family: Theme.font
                    font.pixelSize: Theme.fontSize - 1
                }
                IconBtn {
                    icon: Theme.iTrash
                    label: win.armed ? "sure?" : "wipe"
                    active: win.armed
                    onClicked: {
                        if (!win.armed) { win.armed = true; disarm.restart(); return }
                        win.armed = false
                        Clip.wipe()
                    }
                }
                IconBtn { icon: Theme.iClose; onClicked: win.closeRequested() }
            }

            ListView {
                id: list
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                model: win.shown
                spacing: 2
                boundsBehavior: Flickable.StopAtBounds
                highlightMoveDuration: 0

                delegate: Rectangle {
                    id: row
                    required property var modelData
                    required property int index
                    readonly property bool selected: list.currentIndex === index
                    readonly property bool hasImg: modelData.image && Clip.ready[modelData.id] === true
                    width: list.width
                    height: hasImg ? 96 : 28
                    color: selected ? Theme.surfaceHi : (rm.containsMouse ? Theme.surface : "transparent")
                    border.width: selected ? 1 : 0
                    border.color: Theme.accent

                    Rectangle {   // selection marker, like the bar's active workspace
                        visible: row.selected
                        width: 2
                        height: parent.height
                        color: Theme.accent
                    }
                    Row {
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 34
                        spacing: 10
                        Image {
                            visible: row.hasImg
                            anchors.verticalCenter: parent.verticalCenter
                            width: visible ? 150 : 0
                            height: 84
                            fillMode: Image.PreserveAspectFit
                            asynchronous: true
                            sourceSize.width: 300
                            sourceSize.height: 168
                            source: row.hasImg ? "file://" + Clip.imageOf(row.modelData) : ""
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - (row.hasImg ? 160 : 0)
                            text: (row.modelData.image ? Theme.iImage + "  " : "") + row.modelData.text
                            elide: Text.ElideRight
                            maximumLineCount: 1
                            color: row.selected ? Theme.fg : (row.modelData.image ? Theme.accent : Theme.fg)
                            font.family: Theme.font
                            font.pixelSize: Theme.fontSize
                        }
                    }
                    MouseArea {
                        id: rm
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: win.pick(row.modelData)
                    }
                    Text {   // delete
                        anchors.right: parent.right
                        anchors.rightMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        visible: row.selected
                        text: Theme.iClose
                        color: dm.containsMouse ? Theme.err : Theme.dim
                        font.family: Theme.font
                        font.pixelSize: Theme.fontSize
                        MouseArea {
                            id: dm
                            anchors.fill: parent
                            anchors.margins: -4
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Clip.remove(row.modelData.id)
                        }
                    }
                }
            }

            Text {
                Layout.fillWidth: true
                text: Clip.available ? "enter copy   del remove   esc close" : "cliphist not installed"
                color: Clip.available ? Theme.dim : Theme.err
                font.family: Theme.font
                font.pixelSize: Theme.fontSize - 2
            }
        }
    }
}
