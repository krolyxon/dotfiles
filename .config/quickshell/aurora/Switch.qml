import QtQuick
import QtQuick.Layouts

// A settings row: label (+ optional hint) and glyph's pill toggle on the right; the whole row is clickable.
// The toggle: off = a dark pill with a dim knob on the left, on = the primary fill runs to the right with a dot.
// After glyph-rice (github.com/Nebelung-cloud/glyph-rice, GPL-3.0), prefs/Toggle.qml.
Rectangle {
    id: s
    property string label: ""
    property string hint: ""
    property bool checked: false
    signal toggled(bool on)

    Layout.fillWidth: true
    implicitHeight: Math.max(56, txt.implicitHeight + 20)
    radius: 28
    color: m.containsMouse ? Theme.s2 : "transparent"

    ColumnLayout {
        id: txt
        anchors.left: parent.left
        anchors.leftMargin: 18
        anchors.right: box.left
        anchors.rightMargin: 16
        anchors.verticalCenter: parent.verticalCenter
        spacing: 3
        Text {
            Layout.fillWidth: true
            text: s.label
            color: Theme.fg
            elide: Text.ElideRight
            font.family: Theme.ui
            font.pixelSize: 15
        }
        Lb {
            Layout.fillWidth: true
            visible: s.hint !== ""
            text: s.hint
            wrapMode: Text.WordWrap
            px: 10
        }
    }
    Rectangle {
        id: box
        anchors.right: parent.right
        anchors.rightMargin: 14
        anchors.verticalCenter: parent.verticalCenter
        width: 64
        height: 34
        radius: 17
        color: Theme.s3
        Rectangle {
            x: 4
            y: 4
            width: s.checked ? parent.width - 8 : height
            height: parent.height - 8
            radius: height / 2
            color: s.checked ? Theme.fill : Theme.mute
            Behavior on width { enabled: Theme.motion; NumberAnimation { duration: Theme.t; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.glide } }
            Behavior on color { enabled: Theme.motion; ColorAnimation { duration: Theme.t } }
            Rectangle {
                anchors.right: parent.right
                anchors.rightMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                visible: s.checked
                width: 10
                height: 10
                radius: 5
                color: Theme.fillFg
            }
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
