import QtQuick
import QtQuick.Layouts

// caps label · segment bar · value. fill = the lit segments (white; the accent when it needs attention).
RowLayout {
    id: r
    property string label: ""
    property real frac: 0
    property string valueText: ""
    property color fill: Theme.fill
    Layout.fillWidth: true
    spacing: 12

    Lb {
        Layout.preferredWidth: 78
        elide: Text.ElideRight
        text: r.label
        px: 10
    }
    Seg {
        Layout.fillWidth: true
        Layout.preferredWidth: 100
        Layout.preferredHeight: 6
        n: 24
        f: r.frac
        on: r.fill
    }
    Lb {
        Layout.preferredWidth: 112
        horizontalAlignment: Text.AlignRight
        elide: Text.ElideLeft
        text: r.valueText
        px: 10
        color: Theme.fg
    }
}
