import QtQuick
import QtQuick.Layouts

// A settings row: label + a one-line text pill with the live caret; `submitted` fires on Enter or when focus leaves
// with a changed value, `edited` on every keystroke (live filters)
RowLayout {
    id: f
    property string label: ""
    property string value: ""
    property string placeholder: ""
    signal submitted(string v)
    signal edited(string v)
    Layout.fillWidth: true
    Layout.leftMargin: 18
    Layout.rightMargin: 14
    spacing: 16
    Text {
        Layout.preferredWidth: 200
        visible: f.label !== ""
        text: f.label
        color: Theme.fg
        elide: Text.ElideRight
        font.family: Theme.ui
        font.pixelSize: 15
    }
    Rectangle {
        Layout.fillWidth: true
        implicitHeight: 46
        radius: 23
        color: Theme.s2
        border.width: 1
        border.color: input.activeFocus ? Theme.fill : Theme.s2
        TextInput {
            id: input
            anchors.fill: parent
            anchors.leftMargin: 20
            anchors.rightMargin: 20
            verticalAlignment: TextInput.AlignVCenter
            clip: true
            text: f.value
            color: Theme.fg
            selectionColor: Theme.fill
            selectedTextColor: Theme.fillFg
            font.family: Theme.ui
            font.pixelSize: 15
            cursorDelegate: Rectangle {
                width: 2
                color: Theme.live
                visible: input.activeFocus
                Timer { running: input.activeFocus; interval: 500; repeat: true; onTriggered: parent.opacity = 1 - parent.opacity }
            }
            onTextEdited: f.edited(text)
            onAccepted: { if (text !== f.value) f.submitted(text); focus = false }
            onActiveFocusChanged: if (!activeFocus && text !== f.value) f.submitted(text)
            Keys.onEscapePressed: e => { text = f.value; focus = false; e.accepted = true }
        }
        Text {
            anchors.fill: parent
            anchors.leftMargin: 20
            verticalAlignment: Text.AlignVCenter
            visible: input.text === "" && !input.activeFocus
            text: f.placeholder
            elide: Text.ElideRight
            color: Theme.mute
            font.family: Theme.ui
            font.pixelSize: 15
        }
    }
}
