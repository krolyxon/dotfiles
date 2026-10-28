import QtQuick

// History as a dot matrix (cpu): one column per sample, the top lit dot white, the ones under it grey, the rest unlit.
// Ported from glyph-rice (github.com/Nebelung-cloud/glyph-rice, GPL-3.0), home/Home.qml (system widget).
Item {
    id: s
    property var values: []
    property int slots: 40
    readonly property real gap: 3
    readonly property real d: Math.max(2, (width - (slots - 1) * gap) / slots)
    readonly property int rows: Math.max(3, Math.floor((height + gap) / (d + gap)))
    implicitHeight: 44

    Grid {
        columns: s.slots
        spacing: s.gap
        Repeater {
            model: s.slots * s.rows
            Rectangle {
                required property int index
                readonly property int col: index % s.slots
                readonly property int up: s.rows - Math.floor(index / s.slots)   // rows .. 1, top to bottom
                readonly property int vi: s.values.length - s.slots + col
                readonly property real v: vi >= 0 && vi < s.values.length ? s.values[vi] : 0
                readonly property int h: Math.max(1, Math.round(v * s.rows))
                width: s.d
                height: s.d
                radius: s.d / 2
                color: up === h ? Theme.fill : up < h ? Theme.fade(Theme.fill, 0.45) : Theme.s2
            }
        }
    }
}
