import QtQuick

// A caps label in a pill: tabs, filters, modes, small actions. selected = white pill with black text.
// `dot` adds a small accent dot after the label (unread, live).
Rectangle {
    id: root

    property string text
    property bool selected: false
    property bool dot: false
    property bool filled: false          // a visible pill even when not selected (action buttons on cards)
    property real px: 11
    signal clicked()

    implicitWidth: lab.implicitWidth + 32 + (dot ? 12 : 0)
    implicitHeight: lab.implicitHeight + 20
    radius: height / 2
    color: selected ? Theme.fill : hov.hovered ? (filled ? Theme.mute : Theme.s3) : (filled ? Theme.s3 : "transparent")
    Behavior on color { enabled: Theme.motion; ColorAnimation { duration: Theme.t } }

    Lb {
        id: lab
        anchors.centerIn: parent
        anchors.horizontalCenterOffset: root.dot ? -6 : 0
        text: root.text
        px: root.px
        color: root.selected ? Theme.fillFg : (hov.hovered || root.filled) ? Theme.fg : Theme.grey
    }
    Rectangle {
        visible: root.dot
        anchors.left: lab.right
        anchors.leftMargin: 6
        anchors.verticalCenter: parent.verticalCenter
        width: 6
        height: 6
        radius: 3
        color: Theme.live
    }
    HoverHandler { id: hov; cursorShape: Qt.PointingHandCursor }
    TapHandler { onTapped: root.clicked() }
}
