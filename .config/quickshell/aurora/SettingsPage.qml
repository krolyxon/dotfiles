import QtQuick
import QtQuick.Layouts

// Theme / shell knobs. Everything writes straight to Settings (persisted, applied live).
ColumnLayout {
    id: page
    spacing: 10

    // label + slider + value, for an integer or real setting
    component Knob: RowLayout {
        id: k
        property string label: ""
        property real value: 0
        property real from: 0
        property real to: 1
        property int decimals: 0
        signal moved(real v)
        Layout.fillWidth: true
        spacing: 8
        Text {
            Layout.preferredWidth: 96
            text: k.label
            color: Theme.fg
            font.family: Theme.font
            font.pixelSize: Theme.fontSize
        }
        BarSlider {
            Layout.fillWidth: true
            from: k.from
            to: k.to
            step: 1 / Math.max(1, (k.to - k.from) * (k.decimals ? 100 : 1))
            value: k.value
            onMoved: v => k.moved(k.decimals ? Math.round(v * 100) / 100 : Math.round(v))
        }
        Text {
            Layout.preferredWidth: 40
            horizontalAlignment: Text.AlignRight
            text: k.decimals ? k.value.toFixed(2) : String(k.value)
            color: Theme.fg
            font.family: Theme.font
            font.pixelSize: Theme.fontSize
        }
    }

    SectionLabel { text: "appearance" }

    Knob { label: "font size"; from: 9; to: 18; value: Settings.fontSize; onMoved: v => Settings.fontSize = v }
    Knob { label: "ws icons"; from: 8; to: 18; value: Settings.wsFontSize; onMoved: v => Settings.wsFontSize = v }
    Knob { label: "bar height"; from: 18; to: 36; value: Settings.barHeight; onMoved: v => Settings.barHeight = v }
    Knob { label: "bar alpha"; from: 0.3; to: 1; decimals: 2; value: Settings.barAlpha; onMoved: v => Settings.barAlpha = v }
    Knob { label: "panel alpha"; from: 0.3; to: 1; decimals: 2; value: Settings.panelAlpha; onMoved: v => Settings.panelAlpha = v }

    SectionLabel { text: "accent" }

    GridLayout {
        Layout.fillWidth: true
        columns: 9
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
                Layout.preferredHeight: 26
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

    SectionLabel { text: "desktop" }

    RowLayout {
        Layout.fillWidth: true
        spacing: 6
        IconBtn {
            Layout.fillWidth: true
            icon: Theme.iClock
            label: "clock"
            active: Settings.desktopClock
            onClicked: Settings.desktopClock = !Settings.desktopClock
        }
        IconBtn {
            Layout.fillWidth: true
            icon: Theme.iMusic
            label: "visualizer"
            active: Settings.desktopViz
            onClicked: Settings.desktopViz = !Settings.desktopViz
        }
        IconBtn {
            Layout.fillWidth: true
            icon: Theme.iDock
            label: "dock"
            active: Settings.dock
            onClicked: Settings.dock = !Settings.dock
        }
    }
    Knob { label: "viz bars"; from: 16; to: 128; value: Settings.vizBars; onMoved: v => Settings.vizBars = v }
    Knob { label: "osd ms"; from: 500; to: 4000; value: Settings.osdTimeout; onMoved: v => Settings.osdTimeout = Math.round(v / 100) * 100 }

    Item { Layout.fillHeight: true }

    RowLayout {
        Layout.fillWidth: true
        Text {
            Layout.fillWidth: true
            text: "~/.config/aurora/settings.json"
            elide: Text.ElideLeft
            color: Theme.dim
            font.family: Theme.font
            font.pixelSize: Theme.fontSize - 2
        }
        IconBtn { icon: Theme.iRefresh; label: "reset"; onClicked: Settings.reset() }
    }
}
