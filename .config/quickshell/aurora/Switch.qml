import QtQuick
import QtQuick.Layouts

// label (+ optional hint) and an on/off box; the whole row is clickable (settings app)
Rectangle {
    id: s
    property string label: ""
    property string hint: ""
    property bool checked: false
    signal toggled(bool on)

    Layout.fillWidth: true
    implicitHeight: Math.max(30, txt.implicitHeight + 10)
    color: m.containsMouse ? Theme.surface : "transparent"

    ColumnLayout {
        id: txt
        anchors.left: parent.left
        anchors.right: box.left
        anchors.rightMargin: 10
        anchors.verticalCenter: parent.verticalCenter
        spacing: 0
        Text {
            Layout.fillWidth: true
            text: s.label
            color: Theme.fg
            elide: Text.ElideRight
            font.family: Theme.font
            font.pixelSize: Theme.fontSize
        }
        Text {
            Layout.fillWidth: true
            visible: s.hint !== ""
            text: s.hint
            color: Theme.dim
            wrapMode: Text.WordWrap
            font.family: Theme.font
            font.pixelSize: Theme.fontSize - 2
        }
    }
    Rectangle {   // the switch: square track, knob left (off) / right (on)
        id: box
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        width: 36
        height: 18
        color: s.checked ? Theme.accent : Theme.surfaceHi
        border.width: 1
        border.color: s.checked ? Theme.accent : Theme.line
        Rectangle {
            width: 12
            height: 12
            anchors.verticalCenter: parent.verticalCenter
            x: s.checked ? parent.width - width - 3 : 3
            color: s.checked ? Theme.bg : Theme.dim
        }
    }
    MouseArea {
        id: m
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: s.toggled(!s.checked)
    }
}
