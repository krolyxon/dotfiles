import QtQuick
import Quickshell

// The settings app: a normal Hyprland window (class org.quickshell, title "aurora settings"), opened maximized by a
// window rule. glyph's prefs layout: the sections as a column of Doto words (the selected one large with the live dot),
// the page on the right under a caption, key hints at the bottom. One Loader, so only the shown section runs.
// Tab / Shift+Tab, Up/Down (outside text fields) or Ctrl+J/K = sections, Esc closes.
// Opened with the `settings [section]` IPC. After glyph-rice (github.com/Nebelung-cloud/glyph-rice, GPL-3.0), prefs/Prefs.qml.
FloatingWindow {
    id: win
    property bool opened: false
    property string section: "network"
    signal closeRequested()
    signal sectionRequested(string name)
    signal overlayRequested(string name)

    visible: opened
    title: "aurora settings"
    implicitWidth: 1600
    implicitHeight: 900
    color: Theme.bg
    // closed by the compositor (killactive): keep shell state in sync
    onVisibleChanged: if (!visible && opened) closeRequested()

    readonly property var sections: [
        { id: "network",    word: "network",   caption: "network · wi-fi, wired, tethering" },
        { id: "bluetooth",  word: "bluetooth", caption: "bluetooth · devices, pairing" },
        { id: "sound",      word: "sound",     caption: "sound · levels, devices, apps" },
        { id: "appearance", word: "look",      caption: "look · wallpaper, home screen, colours, sizes" },
        { id: "shell",      word: "shell",     caption: "shell · home screen, dock, osd, notifications" },
        { id: "windows",    word: "windows",   caption: "windows · hyprland gaps, borders, effects, layout" },
        { id: "input",      word: "input",     caption: "input · keyboard, mouse, touchpad" },
        { id: "keybinds",   word: "keys",      caption: "keys · hyprland binds" },
        { id: "display",    word: "display",   caption: "display · monitors, layout, night light" },
        { id: "power",      word: "power",     caption: "power · battery, profiles, idle" },
        { id: "about",      word: "about",     caption: "about · this system" }
    ]
    readonly property int index: {
        for (var i = 0; i < sections.length; i++) if (sections[i].id === section) return i
        return 0
    }
    function cycle(d) { sectionRequested(sections[(index + d + sections.length) % sections.length].id) }
    // typing in a field: arrows belong to it
    function inText() { var a = win.activeFocusItem; return a !== null && a.cursorPosition !== undefined }

    Item {
        id: root
        anchors.fill: parent
        focus: true
        Keys.onPressed: e => {
            var ctrl = e.modifiers & Qt.ControlModifier
            if (e.key === Qt.Key_Escape) { win.closeRequested(); e.accepted = true }
            else if (e.key === Qt.Key_Tab || (ctrl && e.key === Qt.Key_J)) { win.cycle(1); e.accepted = true }
            else if (e.key === Qt.Key_Backtab || (ctrl && e.key === Qt.Key_K)) { win.cycle(-1); e.accepted = true }
        }
        // a click outside the page drops the focus out of text fields (arrows switch sections again)
        MouseArea { anchors.fill: parent; onClicked: root.forceActiveFocus() }

        Item {
            id: stage
            anchors.fill: parent
            Keys.forwardTo: [root]

            // ---- sections ----
            Column {
                id: words
                x: Math.round(Math.min(150, win.width * 0.07))
                anchors.verticalCenter: parent.verticalCenter
                spacing: 12
                Repeater {
                    model: win.sections
                    Row {
                        id: w
                        required property var modelData
                        required property int index
                        readonly property bool on: win.index === index
                        spacing: 20
                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: w.on
                            width: 20
                            height: 20
                            radius: 10
                            color: Theme.live
                        }
                        Num {
                            text: w.modelData.word.toUpperCase()
                            font.pixelSize: w.on ? 76 : 32
                            color: w.on ? Theme.fg : wm.hovered ? Theme.grey : Theme.mute
                            Behavior on font.pixelSize {
                                enabled: Theme.motion
                                NumberAnimation { duration: Theme.t; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.glide }
                            }
                            Behavior on color { enabled: Theme.motion; ColorAnimation { duration: Theme.t } }
                        }
                        HoverHandler { id: wm; cursorShape: Qt.PointingHandCursor }
                        TapHandler { onTapped: { win.sectionRequested(w.modelData.id); root.forceActiveFocus() } }
                    }
                }
            }

            // ---- the page ----
            Item {
                id: pageBox
                x: Math.max(words.x + 560, Math.round(win.width * 0.42))
                y: 96
                width: Math.min(900, win.width - x - 80)
                height: parent.height - y - 110
                Lb {
                    id: caption
                    x: 18
                    text: win.sections[win.index].caption
                }
                Loader {
                    anchors.top: caption.bottom
                    anchors.topMargin: 24
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    active: win.opened
                    sourceComponent: {
                        switch (win.section) {
                        case "bluetooth":  return btC
                        case "sound":      return soundC
                        case "appearance": return appearanceC
                        case "shell":      return shellC
                        case "windows":    return windowsC
                        case "input":      return inputC
                        case "keybinds":   return keysC
                        case "display":    return displayC
                        case "power":      return powerC
                        case "about":      return aboutC
                        default:           return netC
                        }
                    }
                }
            }

            Row {
                x: words.x
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 50
                spacing: 34
                Repeater {
                    model: ["tab · ↑↓ section", "esc close"]
                    Lb { required property string modelData; text: modelData }
                }
            }
        }
        // ↑↓ switch sections unless a text field has the keyboard
        Keys.onUpPressed: e => { if (win.inText()) { e.accepted = false; return } win.cycle(-1) }
        Keys.onDownPressed: e => { if (win.inText()) { e.accepted = false; return } win.cycle(1) }
    }

    Component { id: netC; NetPage { active: true } }
    Component { id: btC; BtPage { active: true } }
    Component { id: soundC; AudioPage {} }
    Component { id: appearanceC; SetAppearance { onOverlayRequested: name => win.overlayRequested(name) } }
    Component { id: shellC; SetShell {} }
    Component { id: windowsC; SetWindows {} }
    Component { id: inputC; SetInput {} }
    Component { id: keysC; SetKeys {} }
    Component { id: displayC; SetDisplay {} }
    Component { id: powerC; SetPower {} }
    Component { id: aboutC; SetAbout {} }
}
