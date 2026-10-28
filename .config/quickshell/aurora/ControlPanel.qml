import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland

// Control panel: a card at the top right, as tall as the shown page (pages scroll when the screen is shorter).
// Header: Doto clock, date, settings + power. Tabs are chips. Slides in from the right.
// After glyph-rice's quick settings (github.com/Nebelung-cloud/glyph-rice, GPL-3.0), quick/Quick.qml.
PanelWindow {
    id: win
    property bool opened: false
    property int tab: 0
    signal tabRequested(int index)
    signal closeRequested()
    signal overlayRequested(string name)
    signal settingsRequested()

    // 0 = closed .. 1 = open; the window stays mapped until the slide-out ends
    property real t: opened ? 1 : 0
    Behavior on t { NumberAnimation { duration: Theme.t; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.glide } }

    visible: t > 0
    anchors { top: true; right: true; bottom: true }
    margins { top: 6; right: 8; bottom: 8 }       // sits just under the bar (bar's exclusive zone is respected)
    implicitWidth: card.width + 24                  // room for the slide
    exclusiveZone: 0
    color: "transparent"
    mask: Region { item: card }                     // the empty part below the card stays click-through
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "aurora-panel"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

    // click anywhere outside to close
    HyprlandFocusGrab {
        windows: [win]
        active: win.opened
        onCleared: win.closeRequested()
    }

    readonly property var tabs: [
        { name: "home", label: "home" },
        { name: "audio", label: "sound" },
        { name: "net", label: "net" },
        { name: "bt", label: "bt" },
        { name: "system", label: "sys" },
        { name: "notifs", label: "notif" }
    ]

    SystemClock { id: clock; precision: SystemClock.Minutes }

    Rectangle {
        id: card
        anchors.right: parent.right
        anchors.rightMargin: -24 * (1 - win.t)
        width: 470
        height: Math.min(parent.height, col.implicitHeight + 44)
        opacity: win.t
        radius: 36
        color: Theme.fade(Theme.s1, Theme.panelAlpha)
        border.width: 1
        border.color: Theme.s2
        focus: true
        Keys.onEscapePressed: win.closeRequested()
        // Tab / Shift+Tab cycle through the tabs (wraps around)
        Keys.onTabPressed: win.tabRequested((win.tab + 1) % win.tabs.length)
        Keys.onBacktabPressed: win.tabRequested((win.tab + win.tabs.length - 1) % win.tabs.length)

        ColumnLayout {
            id: col
            x: 22
            y: 22
            width: parent.width - 44
            height: parent.height - 44
            spacing: 16

            // ---- header: clock, date, settings, power ----
            RowLayout {
                Layout.fillWidth: true
                Layout.leftMargin: 6
                spacing: 14
                Num {
                    text: Theme.hh(clock.date) + ":" + Qt.formatDateTime(clock.date, "mm")
                    font.pixelSize: 44
                }
                Lb {
                    Layout.alignment: Qt.AlignVCenter
                    text: Qt.locale("en_US").toString(clock.date, "ddd d MMM")
                }
                Item { Layout.fillWidth: true }
                IconBtn { implicitHeight: 44; iconSize: 18; icon: Theme.iCog; onClicked: win.settingsRequested() }
                IconBtn { implicitHeight: 44; iconSize: 18; icon: Theme.iPower; onClicked: win.overlayRequested("power") }
            }

            // ---- tabs ----
            Row {
                Layout.fillWidth: true
                spacing: 2
                Repeater {
                    model: win.tabs
                    delegate: Chip {
                        required property var modelData
                        required property int index
                        text: modelData.label
                        selected: win.tab === index
                        dot: modelData.name === "notifs" && Notifs.count > 0 && win.tab !== index
                        onClicked: win.tabRequested(index)
                    }
                }
            }

            StackLayout {
                id: stack
                Layout.fillWidth: true
                Layout.fillHeight: true
                // as tall as the shown page; the card is capped at the screen height and the page scrolls
                Layout.preferredHeight: children[win.tab] ? children[win.tab].implicitHeight : 0
                currentIndex: win.tab

                HomePage {
                    onCloseRequested: win.closeRequested()
                    onOverlayRequested: name => win.overlayRequested(name)
                    onTabRequested: name => {
                        for (var i = 0; i < win.tabs.length; i++) if (win.tabs[i].name === name) win.tabRequested(i)
                    }
                }
                AudioPage {}
                NetPage { active: win.opened && win.tab === 2 }
                BtPage { active: win.opened && win.tab === 3 }
                SysPage {}
                NotifPage {}
            }
        }
    }
}
