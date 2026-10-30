import QtQuick

// One block of the bar: icon, caps label, optional second icon with its own click (activated2), anything else declared
// inside goes after them (the battery capsule, the clock). Side by side in the top bar, stacked in the vertical one.
// Hover = a rounded highlight.
Item {
    id: p
    property string icon: ""
    property string text: ""
    property color tint: Theme.fg
    property color underline: "transparent"   // old style, unused
    property string icon2: ""
    property color tint2: Theme.fg
    property bool vertical: Theme.barVertical
    default property alias extra: row.data
    signal activated(int button)
    signal activated2(int button)
    signal scrolled(int dir)

    implicitWidth: vertical ? Theme.barSize : row.implicitWidth + 22
    implicitHeight: vertical ? row.implicitHeight + 16 : Theme.barSize

    Rectangle {
        anchors.fill: parent
        anchors.topMargin: p.vertical ? 0 : 5
        anchors.bottomMargin: p.vertical ? 0 : 5
        anchors.leftMargin: p.vertical ? 5 : 0
        anchors.rightMargin: p.vertical ? 5 : 0
        radius: Math.min(width, height) / 2
        color: m.containsMouse ? Theme.s2 : "transparent"
    }
    // a row, or a column in the vertical bar. Only `columns` flips (rows and columns both changing pass through 1x1 and
    // warn), and it must match the shown items exactly: Grid leaves a gap for every empty column.
    Grid {
        id: row
        anchors.centerIn: parent
        columns: p.vertical ? 1 : Math.max(1, visibleChildren.length)
        spacing: p.vertical ? 5 : 7
        horizontalItemAlignment: Grid.AlignHCenter
        verticalItemAlignment: Grid.AlignVCenter
        Icon {
            visible: p.icon !== ""
            text: p.icon
            font.pixelSize: 16
            color: p.tint
        }
        Lb {
            visible: p.text !== ""
            text: p.text
            px: 11
            color: p.tint
        }
        Icon {
            id: second
            visible: p.icon2 !== ""
            text: p.icon2
            font.pixelSize: 16
            color: p.tint2
        }
    }
    MouseArea {
        id: m
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        onClicked: mouse => {
            // split at the middle of the gap before the second icon
            var at = p.vertical ? mouse.y - row.y - second.y : mouse.x - row.x - second.x
            if (second.visible && at >= -row.spacing / 2) p.activated2(mouse.button)
            else p.activated(mouse.button)
        }
        onWheel: w => p.scrolled(w.angleDelta.y > 0 ? 1 : -1)
    }
}
