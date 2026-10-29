import QtQuick

// A pill floating over a full-screen view (screenshot viewfinder, editor): the content in a centred row.
// Clicks on it don't fall through to what's under it.
// Ported from glyph-rice (github.com/Nebelung-cloud/glyph-rice, GPL-3.0), shot/Pill.qml.
Rectangle {
    default property alias content: row.data
    property alias spacing: row.spacing
    property real pad: 10

    width: row.width + pad * 2
    height: 56
    radius: height / 2
    color: Theme.s1
    border.width: 1
    border.color: Theme.s2

    MouseArea { anchors.fill: parent }
    Row { id: row; anchors.centerIn: parent }
}
