import QtQuick

// A Nerd Font (Material Design) glyph in a 1em box: the font's line is 1.32em, the padding trims it so icons centre.
// Glyphs come from Theme (Theme.iFoo), never pasted into files.
// Ported from glyph-rice (github.com/Nebelung-cloud/glyph-rice, GPL-3.0), components/Icon.qml.
Text {
    readonly property real lead: -0.16 * font.pixelSize
    font.family: Theme.nf
    font.pixelSize: 19
    topPadding: lead
    bottomPadding: lead
    color: Theme.fg
}
