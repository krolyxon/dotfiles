import QtQuick
import QtQuick.Layouts

// Settings app > Appearance: wallpaper, colour scheme, sizes and transparency (all in Settings, applied live).
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
            Layout.leftMargin: 18
            text: Wall.current !== "" ? Wall.current.replace(Wall.home, "~") : "-"
            elide: Text.ElideLeft
            color: Theme.dim
            font.family: Theme.ui
            font.pixelSize: 14
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
            font.family: Theme.ui
            font.pixelSize: 15
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

        SectionLabel { text: "wallpaper look" }
        Choice {
            label: "drawn as"
            options: [{ value: "dots", label: "mono dots" }, { value: "colour", label: "colour dots" }, { value: "photo", label: "photo" }]
            value: Settings.wallLook
            onPicked: v => Settings.wallLook = v
        }
        Knob { label: "dot size"; from: 6; to: 24; value: Settings.wallPitch; unit: "px"; onMoved: v => Settings.wallPitch = v }
        Knob { label: "brightness"; from: 20; to: 100; value: Settings.wallBright; unit: "%"; onMoved: v => Settings.wallBright = v }
        Switch { label: "dot grid"; hint: "on the desktop when there is no wallpaper"; checked: Settings.dotGrid; onToggled: on => Settings.dotGrid = on }

        SectionLabel { text: "desktop" }
        Switch { label: "24-hour clock"; checked: Settings.clock24; onToggled: on => Settings.clock24 = on }
        Switch { label: "blinking colon"; checked: Settings.blink; onToggled: on => Settings.blink = on }
        Switch { label: "animations"; hint: "panels slide and fade, dots light up in waves"; checked: Settings.motion; onToggled: on => Settings.motion = on }
        Choice {
            label: "app icons"
            options: [{ value: "dots", label: "dots" }, { value: "mono", label: "mono" }, { value: "colour", label: "colour" }]
            value: Settings.appIcons
            onPicked: v => Settings.appIcons = v
        }

        SectionLabel { text: "colours" }
        Text {
            Layout.fillWidth: true
            Layout.leftMargin: 18
            text: "matugen scheme from the wallpaper, accent = its primary"
            elide: Text.ElideRight
            color: Theme.dim
            font.family: Theme.ui
            font.pixelSize: 14
        }
        Flow {
            Layout.fillWidth: true
            spacing: 4
            Repeater {
                model: ["tonal-spot", "vibrant", "expressive", "fidelity", "content", "fruit-salad", "rainbow", "neutral", "monochrome"]
                delegate: IconBtn {
                    required property string modelData
                    implicitHeight: 26
                    label: modelData
                    active: Settings.matuScheme === "scheme-" + modelData
                    onClicked: Settings.matuScheme = "scheme-" + modelData
                }
            }
        }
        Knob { label: "contrast"; from: -1; to: 1; decimals: 2; value: Settings.matuContrast; onMoved: v => Settings.matuContrast = v }

        SectionLabel { text: "sizes" }
        Knob { label: "font size"; from: 9; to: 18; value: Settings.fontSize; onMoved: v => Settings.fontSize = v }
        Knob { label: "workspace icons"; from: 8; to: 18; value: Settings.wsFontSize; onMoved: v => Settings.wsFontSize = v }
        Knob { label: "bar height"; from: 32; to: 56; value: Settings.barSize; onMoved: v => Settings.barSize = v }

        SectionLabel { text: "transparency" }
        Knob { label: "bar opacity"; from: 0.3; to: 1; decimals: 2; value: Settings.barAlpha; onMoved: v => Settings.barAlpha = v }
        Knob { label: "panel opacity"; from: 0.3; to: 1; decimals: 2; value: Settings.panelAlpha; onMoved: v => Settings.panelAlpha = v }
    }
}
