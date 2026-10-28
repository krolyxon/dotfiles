import QtQuick

// Label: Space Mono caps, tracking .14em, grey. Size via `px` (the tracking is derived from it).
// Ported from glyph-rice (github.com/Nebelung-cloud/glyph-rice, GPL-3.0), components/Lb.qml.
Text {
    property real px: 12
    font.family: Theme.mono
    font.pixelSize: px
    font.letterSpacing: px * 0.14
    font.capitalization: Font.AllUppercase
    color: Theme.grey
}
