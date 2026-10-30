import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Notifications

// Toasts as an island at the top centre, under the bar: up to 4 cards, newest on top. Each drops in as a small pill and
// grows into its card; leaving, it shrinks back and the ones below slide up. Hovering holds them all, click = the app's
// default action, the × on hover only drops the toast (the notification stays in the history), other actions are pills.
// After glyph-rice's island (github.com/Nebelung-cloud/glyph-rice, GPL-3.0), glyph/Glyph.qml.
PanelWindow {
    id: win
    property bool suppressed: false      // hidden while the control panel is open
    readonly property int cardW: 520

    visible: stack.count > 0 && !suppressed
    anchors.top: true
    margins.top: Theme.barTop ? 6 : 8
    implicitWidth: cardW
    implicitHeight: 4 * 160 + 20         // fixed; only the cards take input (mask)
    exclusiveZone: 0
    color: "transparent"
    mask: Region { item: col }
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "aurora-notifs"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    // The island's own model: Notifs.popups is a new array on every change, which would restart every card's animation.
    // Entries are snapshots (a notification can close while its card animates out); refs keeps the live object.
    ListModel { id: stack }
    property var refs: ({})

    function imgOf(n) {
        if (n.image && n.image !== "") return n.image
        if (n.appIcon && n.appIcon !== "") return Quickshell.iconPath(n.appIcon, true)
        return ""
    }
    function sync() {
        var want = {}, l = Notifs.popups
        for (var i = 0; i < l.length; i++) want[String(l[i].n.id)] = l[i].n
        for (var j = 0; j < stack.count; j++) {
            var e = stack.get(j)
            if (!e.leaving && !want[e.key]) stack.setProperty(j, "leaving", true)
        }
        for (var k in want) {
            var known = false
            for (var m = 0; m < stack.count; m++) if (stack.get(m).key === k) { known = true; break }
            if (known) continue
            var n = want[k]
            refs[k] = n
            stack.insert(0, { key: k, app: n.appName || "app", summary: n.summary || "", body: n.body || "",
                              icon: imgOf(n), photo: !!n.image && n.image !== "",
                              crit: n.urgency === NotificationUrgency.Critical, leaving: false })
        }
    }
    function forget(key) {
        delete refs[key]
        for (var i = 0; i < stack.count; i++) if (stack.get(i).key === key) { stack.remove(i); return }
    }
    Connections {
        target: Notifs
        function onPopupsChanged() { win.sync() }
    }
    Component.onCompleted: sync()

    // hovering the island holds every toast
    Binding { target: Notifs; property: "hold"; value: hov.hovered }

    Column {
        id: col
        width: win.cardW
        HoverHandler { id: hov }

        Repeater {
            model: stack
            delegate: Item {
                id: c
                required property int index
                required property string key
                required property string app
                required property string summary
                required property string body
                required property string icon
                required property bool photo
                required property bool crit
                required property bool leaving

                readonly property var n: win.refs[key] || null
                // other actions as pills (the default one is the click); read once, the notification may close later
                readonly property var buttons: {
                    var out = [], a = n ? n.actions : []
                    for (var i = 0; i < a.length; i++) if (a[i].identifier !== "default" && a[i].text !== "") out.push(a[i])
                    return out
                }
                readonly property var defaultAction: {
                    var a = n ? n.actions : []
                    for (var i = 0; i < a.length; i++) if (a[i].identifier === "default") return a[i]
                    return null
                }
                // invoke() can close the notification: drop by key afterwards, never touch c.n again
                function run(action) {
                    var k = key
                    try { if (action) action.invoke() } catch (e) {}
                    var nn = win.refs[k]
                    if (nn) Notifs.dropPopup(nn)
                }

                // p 0..1 linear; each phase gets its own ease-out-quart (like glide)
                property real p: 0
                Component.onCompleted: p = Qt.binding(() => leaving ? 0 : 1)
                Behavior on p { enabled: Theme.motion; NumberAnimation { duration: c.leaving ? 450 : 700 } }
                onPChanged: if (leaving && p <= 0) Qt.callLater(win.forget, key)
                onLeavingChanged: if (leaving && !Theme.motion) Qt.callLater(win.forget, key)
                function ph(a, b) { var x = Math.max(0, Math.min(1, (p - a) / (b - a))); return 1 - Math.pow(1 - x, 4) }
                readonly property real drop: ph(0, 0.3)      // the pill drops in
                readonly property real grow: ph(0.25, 0.8)   // and spreads into the card
                readonly property real full: Math.max(86, txt.implicitHeight + 32)

                width: win.cardW
                height: (40 + (full - 40) * grow + 10) * drop   // its slot grows and collapses with it

                Rectangle {
                    id: card
                    width: 140 + (win.cardW - 140) * c.grow
                    height: 40 + (c.full - 40) * c.grow
                    x: (win.cardW - width) / 2
                    y: -24 * (1 - c.drop)
                    opacity: c.drop
                    radius: Math.min(34, height / 2)
                    clip: true
                    color: Theme.s1
                    border.width: 1
                    border.color: c.crit ? Theme.err : Theme.grey

                    MouseArea {
                        id: ma
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: c.defaultAction ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onClicked: c.run(c.defaultAction)
                    }

                    // the content at full size in the middle: text doesn't reflow while the card grows
                    Item {
                        anchors.centerIn: parent
                        width: win.cardW
                        height: c.full
                        opacity: c.ph(0.7, 1)

                        Rectangle {
                            id: ic
                            x: 16
                            anchors.verticalCenter: parent.verticalCenter
                            width: 54
                            height: 54
                            radius: 27
                            color: Theme.s2
                            Icon { anchors.centerIn: parent; visible: !img.visible; text: Theme.iBell; font.pixelSize: 22 }
                            Image {
                                id: img
                                anchors.centerIn: parent
                                width: c.photo && Settings.appIcons === "dots" ? 54 : 30
                                height: width
                                visible: status === Image.Ready
                                source: c.icon
                                sourceSize: Qt.size(width * 2, height * 2)
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                                layer.enabled: Settings.appIcons !== "colour"
                                layer.effect: Settings.appIcons === "mono" ? monoFx : dotFx
                            }
                            Component { id: dotFx; DotMask { step: c.photo ? 3 : 2; circle: c.photo } }
                            Component { id: monoFx; MultiEffect { saturation: -1 } }
                        }
                        Column {
                            id: txt
                            anchors.left: ic.right
                            anchors.leftMargin: 16
                            anchors.right: parent.right
                            anchors.rightMargin: 48
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 2
                            Lb { width: parent.width; elide: Text.ElideRight; px: 10; text: c.app + " · now" }
                            Text {
                                width: parent.width
                                elide: Text.ElideRight
                                text: c.summary
                                font.family: Theme.ui
                                font.pixelSize: 17
                                font.weight: Font.DemiBold
                                color: Theme.fg
                            }
                            Text {
                                width: parent.width
                                visible: c.body !== ""
                                text: c.body
                                textFormat: Text.StyledText
                                wrapMode: Text.Wrap
                                maximumLineCount: 2
                                elide: Text.ElideRight
                                font.family: Theme.ui
                                font.pixelSize: 14
                                color: Theme.fgDim
                                linkColor: Theme.fill
                            }
                            Flow {
                                visible: c.buttons.length > 0
                                width: parent.width
                                topPadding: 8
                                spacing: 6
                                Repeater {
                                    model: c.buttons
                                    delegate: Chip {
                                        required property var modelData
                                        text: modelData.text
                                        filled: true
                                        px: 10
                                        onClicked: c.run(modelData)
                                    }
                                }
                            }
                        }
                        // the newest one carries the live dot; on hover the dot makes room for ×
                        Rectangle {
                            visible: c.index === 0 && !ma.containsMouse && !closeBtn.hovered
                            anchors.right: parent.right
                            anchors.rightMargin: 22
                            anchors.verticalCenter: parent.verticalCenter
                            width: 10
                            height: 10
                            radius: 5
                            color: Theme.live
                        }
                        IconBtn {
                            id: closeBtn
                            readonly property bool hovered: hh.hovered
                            visible: ma.containsMouse || hovered
                            anchors.right: parent.right
                            anchors.rightMargin: 12
                            anchors.verticalCenter: parent.verticalCenter
                            implicitHeight: 30
                            icon: Theme.iClose
                            iconSize: 13
                            onClicked: c.run(null)
                            HoverHandler { id: hh }
                        }
                    }
                }
            }
        }
    }
}
