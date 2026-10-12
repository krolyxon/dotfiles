import QtQuick
import QtQuick.Layouts

Rectangle {
    id: r
    property string icon: ""
    property string title: ""
    property string subtitle: ""
    property string trailing: ""
    property bool current: false
    signal clicked()
    // anything declared inside a ListRow{} lands in the right-hand slot
    default property alias extra: extraRow.data

    Layout.fillWidth: true
    implicitHeight: 42
    color: m.containsMouse ? Theme.surfaceHi : (current ? Theme.surface : "transparent")
    border.width: current ? 1 : 0
    border.color: Theme.accent

    MouseArea {
        id: m
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: r.clicked()
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 10
        anchors.rightMargin: 6
        spacing: 10

        Text {
            text: r.icon
            color: r.current ? Theme.accent : Theme.fg
            font.family: Theme.font
            font.pixelSize: 17
        }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0
            Text {
                text: r.title
                Layout.fillWidth: true
                elide: Text.ElideRight
                color: Theme.fg
                font.family: Theme.font
                font.pixelSize: Theme.fontSize
                font.bold: r.current
            }
            Text {
                visible: r.subtitle !== ""
                text: r.subtitle
                Layout.fillWidth: true
                elide: Text.ElideRight
                color: r.current ? Theme.accent : Theme.dim
                font.family: Theme.font
                font.pixelSize: Theme.fontSize - 3
            }
        }
        Text {
            visible: r.trailing !== ""
            text: r.trailing
            color: Theme.dim
            font.family: Theme.font
            font.pixelSize: Theme.fontSize - 2
        }
        Row { id: extraRow; spacing: 4 }
    }
}
