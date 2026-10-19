import QtQuick
import QtQuick.Layouts

// Settings app > Appearance: wallpaper, accent, sizes and transparency (all in Settings, applied live).
Flickable {
    id: flick
    signal overlayRequested(string name)
    clip: true
    contentWidth: width
    contentHeight: col.implicitHeight
    boundsBehavior: Flickable.StopAtBounds

    Component.onCompleted: Wall.refresh()

    ColumnLayout {
        id: col
        width: flick.width
        spacing: 10

        SectionLabel { text: "wallpaper" }
        Text {
            Layout.fillWidth: true
            text: Wall.current !== "" ? Wall.current.replace(Wall.home, "~") : "-"
            elide: Text.ElideLeft
            color: Theme.dim
            font.family: Theme.font
            font.pixelSize: Theme.fontSize - 1
        }
        RowLayout {
            Layout.fillWidth: true
            spacing: 6
            IconBtn {
                Layout.fillWidth: true
                icon: Theme.iImage
                label: "open picker"
                onClicked: flick.overlayRequested("wall")
            }
            IconBtn {
                Layout.fillWidth: true
                icon: Theme.iShuffle
                label: "random from folder"
                onClicked: Wall.random()
            }
        }
        Text {
            text: "random picks from"
            color: Theme.fg
            font.family: Theme.font
            font.pixelSize: Theme.fontSize
        }
        Flow {
            Layout.fillWidth: true
            spacing: 4
            Repeater {
                model: [""].concat(Wall.folders)
                delegate: IconBtn {
                    required property string modelData
                    implicitHeight: 26
                    label: modelData === "" ? "all" : modelData
                    active: Settings.wallFolder === modelData
                    onClicked: Settings.wallFolder = modelData
                }
            }
        }

        SectionLabel { text: "accent" }
        GridLayout {
            Layout.fillWidth: true
            columns: 17
            columnSpacing: 4
            rowSpacing: 4
            Repeater {
                model: 17                 // "auto" + color0..color15
                delegate: Rectangle {
                    id: sw
                    required property int index
                    readonly property int ci: index - 1          // -1 = auto
                    readonly property bool current: Settings.accentIndex === ci
                    Layout.fillWidth: true
                    Layout.preferredHeight: 28
                    color: ci < 0 ? Theme.surface : Theme.pal[ci]
                    border.width: current ? 2 : 1
                    border.color: current ? Theme.fg : Theme.line
                    Text {
                        anchors.centerIn: parent
                        visible: sw.ci < 0 || sw.current
                        text: sw.ci < 0 ? "auto" : Theme.iCheck
                        color: sw.ci < 0 ? Theme.fg : Theme.bg
                        font.family: Theme.font
                        font.pixelSize: Theme.fontSize - 2
                        font.bold: true
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Settings.accentIndex = sw.ci
                    }
                }
            }
        }

        SectionLabel { text: "sizes" }
        Knob { label: "font size"; from: 9; to: 18; value: Settings.fontSize; onMoved: v => Settings.fontSize = v }
        Knob { label: "workspace icons"; from: 8; to: 18; value: Settings.wsFontSize; onMoved: v => Settings.wsFontSize = v }
        Knob { label: "bar height"; from: 16; to: 36; value: Settings.barHeight; onMoved: v => Settings.barHeight = v }

        SectionLabel { text: "transparency" }
        Knob { label: "bar opacity"; from: 0.3; to: 1; decimals: 2; value: Settings.barAlpha; onMoved: v => Settings.barAlpha = v }
        Knob { label: "panel opacity"; from: 0.3; to: 1; decimals: 2; value: Settings.panelAlpha; onMoved: v => Settings.panelAlpha = v }
    }
}
