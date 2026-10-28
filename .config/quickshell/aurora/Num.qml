import QtQuick

// Numbers and short words in Doto (dot matrix, round dots, black weight). Never smaller than 26px.
// Doto's line box is 1.2em; the negative padding trims it to ~.85em (lineHeight does nothing on a one-line Text).
// Extra space goes on top of it: `topPadding: lead + 8`.
// Ported from glyph-rice (github.com/Nebelung-cloud/glyph-rice, GPL-3.0), components/Num.qml.
Text {
    readonly property real lead: -0.175 * font.pixelSize
    font.family: Theme.dot
    font.pixelSize: 44
    font.weight: Font.Black
    font.variableAxes: ({ "ROND": 100, "wght": 900 })
    topPadding: lead
    bottomPadding: lead
    color: Theme.fg
}
