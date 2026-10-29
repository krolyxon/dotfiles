import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Wayland

// Screenshot editor (click the card after a shot): the screen almost dark, the shot in a frame with corner dots like the
// viewfinder; tools as chips in a pill, inks as circles, sizes as dots. Marks live in the shot's pixels and are baked in
// with grabToImage at the shot's own size: Ctrl+C / Enter = copy (a /tmp file: the shot's own if it was one, a new one
// if it was kept, so a saved shot is never changed), Ctrl+S = also save to ~/pix/ss. P A R B T tool, 1-4 ink, [ ] size,
// Ctrl+Z undo, Esc discards. The inks are content baked into the image, not UI: the one place with fixed colours (+ the accent).
// After glyph-rice (github.com/Nebelung-cloud/glyph-rice, GPL-3.0), shot/Editor.qml.
Scope {
    id: root

    readonly property var tools: ["pen", "arrow", "rect", "blur", "text"]
    readonly property var hotkeys: [Qt.Key_P, Qt.Key_A, Qt.Key_R, Qt.Key_B, Qt.Key_T]
    readonly property var inks: ["#FF3B30", "#FFFFFF", "#000000", Theme.fill]
    readonly property var sizes: [3, 6, 12]          // stroke in logical px; in the shot x dpr

    readonly property string shot: Shot.editing
    property int tool: 0
    property int ink: 0
    property int size: 1
    property var marks: []    // {k: "pen", c, w, pts} · {k: "arrow" | "rect" | "blur", c, w, x1, y1, x2, y2} · {k: "text", c, s, x, y, t}
    property var live: null   // the mark being dragged right now
    readonly property var scr: Shot.scr || Quickshell.screens[0]
    readonly property real dpr: scr ? scr.devicePixelRatio : 1
    readonly property real w: sizes[size] * dpr

    onShotChanged: {
        if (shot === "") return
        marks = []
        live = null
        typing.visible = false
        st.forceActiveFocus()
    }
    function close() { Shot.editing = "" }

    function commitWord() {
        if (!typing.visible) return
        if (typing.text.trim() !== "")
            marks = marks.concat([{ k: "text", c: inks[ink], s: typing.font.pixelSize, x: typing.x, y: typing.y, t: typing.text }])
        typing.visible = false
        st.forceActiveFocus()
    }

    // keep: also into ~/pix/ss (Shot.done copies it there and to the clipboard)
    function finish(keep) {
        commitWord()
        var path = Shot.isTemp(shot) ? shot : Shot.tempPath()
        canvas.grabToImage(function (r) {
            if (!r.saveToFile(path)) {
                Quickshell.execDetached(["notify-send", "-a", "aurora", "-u", "critical", "screenshot", "couldn't write " + path])
                return
            }
            Shot.done(path, keep, false)
            root.close()
        }, Qt.size(img.implicitWidth, img.implicitHeight))
    }

    PanelWindow {
        id: win

        property real t: root.shot !== "" ? 1 : 0
        Behavior on t { NumberAnimation { duration: Theme.t; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.glide } }

        screen: root.scr
        visible: t > 0
        anchors { left: true; right: true; top: true; bottom: true }
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: root.shot !== "" ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
        WlrLayershell.namespace: "aurora-shot-edit"

        Rectangle { anchors.fill: parent; color: Theme.fade(Theme.bg, 0.96); opacity: win.t }

        Item {
            id: st
            anchors.fill: parent
            focus: true
            Keys.onPressed: e => {
                var t = root.hotkeys.indexOf(e.key), ctrl = (e.modifiers & Qt.ControlModifier) !== 0
                if (e.key === Qt.Key_Escape) root.close()
                else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter || (ctrl && e.key === Qt.Key_C)) root.finish(false)
                else if (ctrl && e.key === Qt.Key_S) root.finish(true)
                else if (ctrl && e.key === Qt.Key_Z) root.marks = root.marks.slice(0, -1)
                else if (ctrl) return
                else if (t >= 0) root.tool = t
                else if (e.key >= Qt.Key_1 && e.key <= Qt.Key_4) root.ink = e.key - Qt.Key_1
                else if (e.key === Qt.Key_BracketLeft) root.size = Math.max(0, root.size - 1)
                else if (e.key === Qt.Key_BracketRight) root.size = Math.min(2, root.size + 1)
                else return
                e.accepted = true
            }

            // the shot fits between the labels and the pill, never above 1:1; grows in from 96%
            Item {
                id: frame
                readonly property real fit: Math.min(1 / root.dpr, (st.width - 240) / Math.max(1, img.implicitWidth),
                                                     (st.height - 140 - 220) / Math.max(1, img.implicitHeight))
                width: img.implicitWidth * fit
                height: img.implicitHeight * fit
                x: (st.width - width) / 2
                y: 140 + (st.height - 140 - 220 - height) / 2
                opacity: win.t
                scale: 0.96 + 0.04 * win.t

                Item {
                    id: canvas
                    width: img.implicitWidth
                    height: img.implicitHeight
                    scale: frame.fit
                    transformOrigin: Item.TopLeft

                    Image {
                        id: img
                        source: root.shot !== "" ? "file://" + root.shot : ""
                        cache: false            // saved over the same path: read it again
                        smooth: true
                        mipmap: true
                    }
                    Repeater {
                        // the live mark is separate: only its delegate is rebuilt on every mouse step
                        model: root.marks
                        Mark { required property var modelData; m: modelData; src: img }
                    }
                    Repeater {
                        model: root.live ? [root.live] : []
                        Mark { required property var modelData; m: modelData; src: img }
                    }

                    TextInput {
                        id: typing
                        visible: false
                        font.family: Theme.ui
                        font.pixelSize: root.w * 6
                        font.weight: Font.DemiBold
                        color: root.inks[root.ink]
                        selectionColor: Theme.s3
                        cursorDelegate: Rectangle { width: 2 * root.dpr; color: Theme.live }    // the caret is live
                        onAccepted: root.commitWord()
                        Keys.onEscapePressed: { visible = false; st.forceActiveFocus() }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: root.tool === 4 ? Qt.IBeamCursor : Qt.CrossCursor
                        onPressed: e => {
                            root.commitWord()
                            var c = root.inks[root.ink]
                            if (root.tool === 0) root.live = { k: "pen", c: c, w: root.w, pts: [Qt.point(e.x, e.y)] }
                            else if (root.tool === 4) {
                                typing.text = ""
                                typing.x = e.x
                                typing.y = e.y - typing.height / 2
                                typing.visible = true
                                typing.forceActiveFocus()
                            } else root.live = { k: root.tools[root.tool], c: c, w: root.w, x1: e.x, y1: e.y, x2: e.x, y2: e.y }
                        }
                        onPositionChanged: e => {
                            var l = root.live
                            if (!l) return
                            // a stroke is copied on every step (O(n^2)): fine for strokes of thousands of points
                            if (l.k === "pen") root.live = Object.assign({}, l, { pts: l.pts.concat([Qt.point(e.x, e.y)]) })
                            else root.live = Object.assign({}, l, { x2: e.x, y2: e.y })
                        }
                        onReleased: {
                            var l = root.live
                            root.live = null
                            if (l && (l.k === "pen" ? l.pts.length > 1 : Math.hypot(l.x2 - l.x1, l.y2 - l.y1) > 4 * root.dpr))
                                root.marks = root.marks.concat([l])
                        }
                    }
                }

                // frame and corner dots, like the viewfinder
                Rectangle { anchors.fill: parent; anchors.margins: -1; color: "transparent"; border.width: 1; border.color: Theme.s3 }
                Repeater {
                    model: 4
                    Rectangle {
                        required property int index
                        x: (index % 2 ? frame.width : 0) - 6
                        y: (index > 1 ? frame.height : 0) - 6
                        width: 12
                        height: 12
                        radius: 6
                        color: Theme.fill
                    }
                }
                Item {
                    y: -height - 18
                    width: parent.width
                    height: dims.height
                    Lb { x: 2; anchors.bottom: parent.bottom; text: "edit · " + root.tools[root.tool]; color: Theme.fg }
                    Row {
                        anchors.right: parent.right
                        anchors.rightMargin: 2
                        spacing: 14
                        Lb { anchors.bottom: parent.bottom; text: root.marks.length + (root.marks.length === 1 ? " mark" : " marks") }
                        Num { id: dims; text: img.implicitWidth + "×" + img.implicitHeight; font.pixelSize: 44 }
                    }
                }
            }

            // tools as chips; then inks as circles and sizes as dots. They slide up from the bottom
            Column {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 44 - 24 * (1 - win.t)
                opacity: win.t
                spacing: 12
                Pill {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 6
                    Repeater {
                        model: root.tools
                        Chip {
                            required property string modelData
                            required property int index
                            anchors.verticalCenter: parent.verticalCenter
                            text: modelData
                            selected: index === root.tool
                            onClicked: { root.commitWord(); root.tool = index }
                        }
                    }
                    Sep {}
                    Repeater {
                        model: root.inks
                        // the chosen ink in a ring
                        Item {
                            required property color modelData
                            required property int index
                            width: 30
                            height: 36
                            Rectangle {
                                anchors.centerIn: parent
                                width: 26
                                height: 26
                                radius: 13
                                color: "transparent"
                                border.width: 1.5
                                border.color: index === root.ink ? Theme.fg : "transparent"
                            }
                            Rectangle {
                                anchors.centerIn: parent
                                width: 16
                                height: 16
                                radius: 8
                                color: modelData
                                border.width: 1
                                border.color: Theme.s3
                            }
                            TapHandler { onTapped: root.ink = index }
                            HoverHandler { cursorShape: Qt.PointingHandCursor }
                        }
                    }
                    Sep {}
                    Repeater {
                        model: root.sizes
                        Item {
                            required property int modelData
                            required property int index
                            width: 26
                            height: 36
                            Rectangle {
                                anchors.centerIn: parent
                                width: modelData + 4
                                height: width
                                radius: width / 2
                                color: index === root.size ? Theme.fill : Theme.mute
                                Behavior on color { enabled: Theme.motion; ColorAnimation { duration: Theme.t } }
                            }
                            TapHandler { onTapped: root.size = index }
                            HoverHandler { cursorShape: Qt.PointingHandCursor }
                        }
                    }
                    Item { width: 8; height: 36 }
                }
                Pill {
                    anchors.horizontalCenter: parent.horizontalCenter
                    height: 36
                    pad: 22
                    spacing: 28
                    Repeater {
                        model: ["p a r b t tool", "1-4 ink", "[ ] size", "ctrl+z undo", "ctrl+c copy", "ctrl+s save", "esc discard"]
                        Lb { required property string modelData; anchors.verticalCenter: parent.verticalCenter; text: modelData; px: 10 }
                    }
                }
            }
        }
    }

    // separator in the pill: a mute dot
    component Sep: Item {
        width: 18
        height: 36
        Rectangle { anchors.centerIn: parent; width: 4; height: 4; radius: 2; color: Theme.mute }
    }

    // one mark, in the shot's pixels
    component Mark: Item {
        id: mk
        property var m
        property Item src        // the shot, for blur (the file's ids aren't visible in an inline component)
        readonly property real x0: Math.min(m.x1, m.x2)
        readonly property real y0: Math.min(m.y1, m.y2)
        readonly property real w0: Math.abs(m.x2 - m.x1)
        readonly property real h0: Math.abs(m.y2 - m.y1)

        Loader {
            sourceComponent: ({ pen: pen, arrow: arrow, rect: rectC, blur: blur, text: word })[mk.m.k]
        }

        Component {
            id: pen
            Shape {
                preferredRendererType: Shape.CurveRenderer
                ShapePath {
                    strokeColor: mk.m.c
                    strokeWidth: mk.m.w
                    fillColor: "transparent"
                    capStyle: ShapePath.RoundCap
                    joinStyle: ShapePath.RoundJoin
                    PathPolyline { path: mk.m.pts }
                }
            }
        }
        Component {
            id: arrow
            Shape {
                id: ar
                // the head is a triangle 4 strokes long, the shaft ends at its base
                readonly property real a: Math.atan2(mk.m.y2 - mk.m.y1, mk.m.x2 - mk.m.x1)
                readonly property real hl: mk.m.w * 4
                readonly property point base: Qt.point(mk.m.x2 - Math.cos(a) * hl * 0.8, mk.m.y2 - Math.sin(a) * hl * 0.8)
                preferredRendererType: Shape.CurveRenderer
                ShapePath {
                    strokeColor: mk.m.c
                    strokeWidth: mk.m.w
                    fillColor: "transparent"
                    capStyle: ShapePath.RoundCap
                    PathPolyline { path: [Qt.point(mk.m.x1, mk.m.y1), ar.base] }
                }
                ShapePath {
                    strokeColor: "transparent"
                    fillColor: mk.m.c
                    PathPolyline {
                        path: [Qt.point(mk.m.x2, mk.m.y2),
                               Qt.point(mk.m.x2 - Math.cos(ar.a - 0.45) * ar.hl, mk.m.y2 - Math.sin(ar.a - 0.45) * ar.hl),
                               Qt.point(mk.m.x2 - Math.cos(ar.a + 0.45) * ar.hl, mk.m.y2 - Math.sin(ar.a + 0.45) * ar.hl),
                               Qt.point(mk.m.x2, mk.m.y2)]
                    }
                }
            }
        }
        Component {
            id: rectC
            Rectangle {
                x: mk.x0 - mk.m.w / 2
                y: mk.y0 - mk.m.w / 2
                width: mk.w0 + mk.m.w
                height: mk.h0 + mk.m.w
                color: "transparent"
                border.width: mk.m.w
                border.color: mk.m.c
            }
        }
        // blur: that part of the shot in big pixels (passwords, faces, addresses)
        Component {
            id: blur
            ShaderEffectSource {
                readonly property real px: mk.m.w * 3
                x: mk.x0
                y: mk.y0
                width: mk.w0
                height: mk.h0
                sourceItem: mk.src
                sourceRect: Qt.rect(mk.x0, mk.y0, mk.w0, mk.h0)
                textureSize: Qt.size(Math.max(1, Math.ceil(mk.w0 / px)), Math.max(1, Math.ceil(mk.h0 / px)))
                smooth: false
            }
        }
        Component {
            id: word
            Text {
                x: mk.m.x
                y: mk.m.y
                text: mk.m.t
                font.family: Theme.ui
                font.pixelSize: mk.m.s
                font.weight: Font.DemiBold
                color: mk.m.c
                style: Text.Outline
                styleColor: Qt.colorEqual(mk.m.c, "#000000") ? "#FFFFFF" : "#000000"
            }
        }
    }
}
