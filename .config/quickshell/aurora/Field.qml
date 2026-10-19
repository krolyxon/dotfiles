import QtQuick
import QtQuick.Layouts

// label + one-line text input; `submitted` fires on Enter or when focus leaves with a changed value (settings app)
RowLayout {
    id: f
    property string label: ""
    property string value: ""
    property string placeholder: ""
    signal submitted(string v)
    signal edited(string v)          // every keystroke (live filters)
    Layout.fillWidth: true
    spacing: 8
    Text {
        Layout.preferredWidth: 150
        text: f.label
        color: Theme.fg
        elide: Text.ElideRight
        font.family: Theme.font
        font.pixelSize: Theme.fontSize
    }
    Rectangle {
        Layout.fillWidth: true
        implicitHeight: 28
        color: Theme.surface
        border.width: 1
        border.color: input.activeFocus ? Theme.accent : Theme.line
        TextInput {
            id: input
            anchors.fill: parent
            anchors.leftMargin: 8
            anchors.rightMargin: 8
            verticalAlignment: TextInput.AlignVCenter
            clip: true
            text: f.value
            color: Theme.fg
            selectionColor: Theme.accent
            selectedTextColor: Theme.bg
            font.family: Theme.font
            font.pixelSize: Theme.fontSize
            onTextEdited: f.edited(text)
            onAccepted: { if (text !== f.value) f.submitted(text); focus = false }
            onActiveFocusChanged: if (!activeFocus && text !== f.value) f.submitted(text)
            Keys.onEscapePressed: e => { text = f.value; focus = false; e.accepted = true }
        }
        Text {
            anchors.fill: parent
            anchors.leftMargin: 8
            verticalAlignment: Text.AlignVCenter
            visible: input.text === "" && !input.activeFocus
            text: f.placeholder
            color: Theme.dim
            font.family: Theme.font
            font.pixelSize: Theme.fontSize
        }
    }
}
