import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland

// The screenshot viewfinder over the frozen frame (Shot.open), and what follows a shot.
// Viewfinder: everything outside the selection dims, a dotted crosshair across the screen, the frame is a 1px line with
// dotted thirds and corner dots, mode + size above it; a loupe at the cursor (pixels as dots in a circle, coordinates and
// the colour under it). Drag = region, click = window / screen, Space = window mode, Tab = next mode, T = timer,
// Enter / Ctrl+C = copy (a file in /tmp only), Ctrl+S = save to ~/pix/ss + copy (whole screen without a selection),
// Esc = cancel. Modes and timer are chips in a pill at the bottom.
// After the shot: the area flashes (recording: a live-coloured frame around it) and a card slides in at the bottom
// right for a few seconds (longer while hovered): click the shot to edit it (ShotEditor), "save" keeps it.
// After glyph-rice (github.com/Nebelung-cloud/glyph-rice, GPL-3.0), shot/Shot.qml.
Scope {
    id: root

    // ui state, logical px relative to the screen
    property rect drag: Qt.rect(0, 0, 0, 0)       // width 0 = nothing selected
    property real mx: 0
    property real my: 0
    readonly property var hover: {
        var l = Shot.wins
        for (var i = 0; i < l.length; i++)
            if (mx >= l[i].x && mx < l[i].x + l[i].w && my >= l[i].y && my < l[i].y + l[i].h) return l[i]
        return null
    }
    readonly property rect sel: Shot.mode === 2 ? Qt.rect(0, 0, stage.width, stage.height)
        : Shot.mode === 1 ? (hover ? Qt.rect(hover.x, hover.y, hover.w, hover.h) : Qt.rect(0, 0, 0, 0))
        : drag
    readonly property real k: frozenImg.sourceSize.width / Math.max(1, stage.width)   // frame px per logical px

    function fire(keep) { Shot.fire(sel, frozenImg.sourceSize, keep) }
    function cycle(n) {
        var c = Rec.available ? 4 : 3
        Shot.mode = (Shot.mode + n + c) % c
    }

    Connections {
        target: Shot
        function onAimingChanged() {
            if (!Shot.aiming) return
            root.drag = Qt.rect(0, 0, 0, 0)
            if (Shot.cursor.x >= 0) { root.mx = Shot.cursor.x; root.my = Shot.cursor.y }
            stage.forceActiveFocus()
        }
        function onFired() { out.stop(); stay.stop(); fx.restart() }
    }

    // ============ viewfinder ============
    PanelWindow {
        id: aim

        // opens at once (the frame already matches the screen), fades out; Shot.snap = gone without the fade
        property real t: Shot.aiming ? 1 : 0
        Behavior on t {
            enabled: !Shot.snap
            NumberAnimation { duration: Theme.t; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.glide }
        }

        screen: Shot.scr || Quickshell.screens[0]
        visible: t > 0
        anchors { left: true; right: true; top: true; bottom: true }
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: Shot.aiming ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
        WlrLayershell.namespace: "aurora-shot"

        Item {
            id: stage
            anchors.fill: parent
            opacity: Shot.aiming ? 1 : aim.t
            focus: true
            Keys.onPressed: e => {
                var ctrl = (e.modifiers & Qt.ControlModifier) !== 0
                if (e.key === Qt.Key_Escape) Shot.close()
                else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter || (ctrl && e.key === Qt.Key_C)) root.fire(false)
                else if (ctrl && e.key === Qt.Key_S) root.fire(true)
                else if (e.key === Qt.Key_Space) Shot.mode = 1
                else if (e.key === Qt.Key_Tab) root.cycle(1)
                else if (e.key === Qt.Key_Backtab) root.cycle(-1)
                else if (e.key === Qt.Key_T) Shot.delay = (Shot.delay + 1) % Shot.delays.length
                else return
                e.accepted = true
            }

            Image {
                id: frozenImg
                anchors.fill: parent
                source: Shot.frozen !== "" ? "file://" + Shot.frozen : ""   // shared cache with the loupe and the picker
            }

            // outside the frame dims; slightly while nothing is selected
            Item {
                anchors.fill: parent
                opacity: aim.t
                readonly property color c: Theme.fade(Theme.bg, root.sel.width > 0 ? 0.74 : 0.35)
                readonly property rect r: root.sel.width > 0 ? root.sel : Qt.rect(0, 0, 0, 0)
                Rectangle { width: parent.width; height: parent.r.y; color: parent.c }
                Rectangle { y: parent.r.y + parent.r.height; width: parent.width; height: parent.height - y; color: parent.c }
                Rectangle { y: parent.r.y; width: parent.r.x; height: parent.r.height; color: parent.c }
                Rectangle { x: parent.r.x + parent.r.width; y: parent.r.y; width: parent.width - x; height: parent.r.height; color: parent.c }
            }

            // crosshair: dotted lines across the screen
            Dots { y: Math.round(root.my) - 4; width: parent.width; height: 8; opacity: 0.5 * aim.t }
            Dots { x: Math.round(root.mx) - 4; width: 8; height: parent.height; opacity: 0.5 * aim.t }

            // frame: 1px line, thirds as dots, dots on the corners; mode and size above it
            Item {
                id: vf
                visible: root.sel.width > 0
                opacity: aim.t
                x: root.sel.x
                y: root.sel.y
                width: root.sel.width
                height: root.sel.height

                Rectangle { anchors.fill: parent; color: "transparent"; border.width: 1; border.color: Theme.fg }
                Repeater {
                    model: 2
                    Item {
                        required property int index
                        anchors.fill: parent
                        Dots { x: parent.width * (index + 1) / 3 - 4; width: 8; height: parent.height; opacity: 0.3 }
                        Dots { y: parent.height * (index + 1) / 3 - 4; width: parent.width; height: 8; opacity: 0.3 }
                    }
                }
                Repeater {
                    model: 4
                    Rectangle {
                        required property int index
                        x: (index % 2 ? vf.width : 0) - 6
                        y: (index > 1 ? vf.height : 0) - 6
                        width: 12
                        height: 12
                        radius: 6
                        color: Theme.fill
                    }
                }

                // above the frame; inside it near the top edge
                Item {
                    y: vf.y > 70 ? -height - 18 : 18
                    width: parent.width
                    height: dims.height
                    Row {
                        x: 2
                        anchors.bottom: parent.bottom
                        spacing: 10
                        // recording: the live dot, the one live thing on screen
                        Rectangle {
                            visible: Shot.mode === 3
                            anchors.verticalCenter: parent.verticalCenter
                            width: 10
                            height: 10
                            radius: 5
                            color: Theme.live
                        }
                        Lb { text: Shot.modes[Shot.mode]; color: Theme.fg }
                    }
                    Row {
                        anchors.right: parent.right
                        anchors.rightMargin: 2
                        spacing: 14
                        Lb { anchors.bottom: parent.bottom; text: Math.round(root.sel.width * root.k) + "×" + Math.round(root.sel.height * root.k) + " px" }
                        Num { id: dims; text: Math.round(root.sel.width) + "×" + Math.round(root.sel.height); font.pixelSize: 44 }
                    }
                }
            }

            // loupe: the pixels under the cursor x12, each a dot (DotMask with a pixel's step); coordinates and colour below
            Item {
                id: loupe
                readonly property int px: Math.floor(root.mx * root.k)
                readonly property int py: Math.floor(root.my * root.k)
                readonly property int zoom: 12
                opacity: aim.t
                x: root.mx + 24 + width > stage.width ? root.mx - 24 - width : root.mx + 24
                y: root.my + 24 + height > stage.height ? root.my - 24 - height : root.my + 24
                width: 180
                height: 240

                // the pixel's colour: drawn into a 1x1 canvas hidden under the loupe
                Canvas {
                    id: picker
                    property string hex: "#000000"
                    x: 90
                    y: 90
                    width: 1
                    height: 1
                    onImageLoaded: requestPaint()
                    onPaint: {
                        var g = getContext("2d"), src = frozenImg.source.toString()
                        if (src === "") return
                        if (!isImageLoaded(src)) { loadImage(src); return }
                        g.drawImage(src, loupe.px, loupe.py, 1, 1, 0, 0, 1, 1)
                        var d = g.getImageData(0, 0, 1, 1).data, h = "#"
                        for (var i = 0; i < 3; i++) h += (d[i] < 16 ? "0" : "") + d[i].toString(16)
                        hex = h.toUpperCase()
                    }
                    Connections {
                        target: loupe
                        function onPxChanged() { picker.requestPaint() }
                        function onPyChanged() { picker.requestPaint() }
                    }
                }

                Rectangle { x: 6; y: 6; width: 168; height: 168; radius: 84; color: Theme.bg }
                // 13 x 13 pixels; the dot grid lines up with them: the centre is the middle of the 7th cell
                Item {
                    x: 12
                    y: 12
                    width: 13 * loupe.zoom
                    height: 13 * loupe.zoom
                    layer.enabled: aim.visible
                    layer.effect: DotMask { step: loupe.zoom; circle: true }
                    Image {
                        source: frozenImg.source
                        smooth: false
                        width: frozenImg.sourceSize.width * loupe.zoom
                        height: frozenImg.sourceSize.height * loupe.zoom
                        x: (6 - loupe.px) * loupe.zoom
                        y: (6 - loupe.py) * loupe.zoom
                    }
                }
                Rectangle { x: 80; y: 80; width: 20; height: 20; radius: 10; color: "transparent"; border.width: 1.5; border.color: Theme.fg }
                Ring { width: 180; height: 180; n: 48; dot: 3 }

                Pill {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    height: 44
                    pad: 18
                    spacing: 12
                    Num { anchors.verticalCenter: parent.verticalCenter; text: Math.round(root.mx) + " · " + Math.round(root.my); font.pixelSize: 26 }
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 12
                        height: 12
                        radius: 6
                        color: picker.hex
                        border.width: 1
                        border.color: Theme.s3
                    }
                    Lb { anchors.verticalCenter: parent.verticalCenter; text: picker.hex; px: 11 }
                }
            }

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.CrossCursor
                property point from
                onPositionChanged: e => {
                    root.mx = e.x
                    root.my = e.y
                    if (pressed && (Shot.mode === 0 || Shot.mode === 3))
                        root.drag = Qt.rect(Math.min(from.x, e.x), Math.min(from.y, e.y), Math.abs(e.x - from.x), Math.abs(e.y - from.y))
                }
                onPressed: e => {
                    if (Shot.mode === 1 || Shot.mode === 2) { root.fire(false); return }   // window / screen: a click copies
                    from = Qt.point(e.x, e.y)
                    root.drag = Qt.rect(e.x, e.y, 0, 0)
                }
            }

            // modes and timer as chips in a pill, the keys under it; they slide up from the bottom
            Column {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 44 - 24 * (1 - aim.t)
                opacity: aim.t
                spacing: 12
                Pill {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 6
                    Repeater {
                        model: Shot.modes
                        Chip {
                            required property string modelData
                            required property int index
                            anchors.verticalCenter: parent.verticalCenter
                            visible: index !== 3 || Rec.available
                            text: modelData
                            selected: index === Shot.mode
                            onClicked: Shot.mode = index
                        }
                    }
                    Item {
                        width: 18
                        height: 36
                        Rectangle { anchors.centerIn: parent; width: 4; height: 4; radius: 2; color: Theme.mute }
                    }
                    Chip {
                        anchors.verticalCenter: parent.verticalCenter
                        text: Shot.delay > 0 ? Shot.delays[Shot.delay] + "s" : "timer"
                        selected: Shot.delay > 0
                        onClicked: Shot.delay = (Shot.delay + 1) % Shot.delays.length
                    }
                }
                Pill {
                    anchors.horizontalCenter: parent.horizontalCenter
                    height: 36
                    pad: 22
                    spacing: 28
                    Repeater {
                        model: ["drag select", "space window", "tab mode", "t timer", "ctrl+c copy", "ctrl+s save", "esc cancel"]
                        Lb { required property string modelData; anchors.verticalCenter: parent.verticalCenter; text: modelData; px: 10 }
                    }
                }
            }
        }
    }

    // ============ after the shot: the area flashes, the shot slides in as a card at the bottom right ============
    PanelWindow {
        id: fired
        screen: Shot.scr || Quickshell.screens[0]
        visible: false
        anchors { left: true; right: true; top: true; bottom: true }
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        mask: Region { item: Shot.lastRec ? null : card }    // clicks pass through everywhere but the card
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        WlrLayershell.namespace: "aurora-shot-done"

        // flash: the shot area lights up and fades. Recording: a live frame just outside it, no fill and no glow
        // (the recorder starts while it fades, it must stay out of the video)
        Rectangle {
            id: flash
            readonly property real o: Shot.lastRec ? 4 : 0
            x: Shot.lastRect.x - o
            y: Shot.lastRect.y - o
            width: Shot.lastRect.width + o * 2
            height: Shot.lastRect.height + o * 2
            color: Shot.lastRec ? "transparent" : Theme.fade(Theme.fg, 0.12)
            border.width: 2
            border.color: Shot.lastRec ? Theme.live : Theme.fill
            layer.enabled: fired.visible && !Shot.lastRec
            layer.effect: MultiEffect {
                shadowEnabled: true
                shadowColor: Theme.glow
                shadowBlur: 0.7
                blurMax: 20
                shadowHorizontalOffset: 0
                shadowVerticalOffset: 0
            }
        }

        // card: rounded 40, the shot rounded 24 inside it (concentric)
        Rectangle {
            id: card
            property real t: 0
            visible: !Shot.lastRec
            x: fired.width - 28 - width + 48 * (1 - t)
            y: fired.height - 28 - height
            opacity: t
            width: 360
            height: col.height + 32
            radius: 40
            color: Theme.s1
            border.width: 1
            border.color: Theme.s2

            Column {
                id: col
                x: 16
                y: 16
                width: parent.width - 32
                spacing: 16
                Item {
                    width: parent.width
                    height: 184
                    TapHandler { onTapped: { fx.stop(); stay.stop(); out.stop(); fired.visible = false; Shot.edit() } }
                    HoverHandler { cursorShape: Qt.PointingHandCursor }
                    layer.enabled: fired.visible
                    layer.effect: MultiEffect { maskEnabled: true; maskSource: thumbMask; maskThresholdMin: 0.5; maskSpreadAtMin: 1 }
                    Rectangle { anchors.fill: parent; color: Theme.s2 }
                    Image {
                        anchors.fill: parent
                        source: Shot.last !== "" ? "file://" + Shot.last : ""
                        sourceSize: Qt.size(328, 184)
                        fillMode: Image.PreserveAspectCrop
                        cache: false            // the editor saves over the same path
                    }
                }
                Item {
                    width: parent.width
                    height: cdims.height
                    Num { id: cdims; x: 8; text: Shot.lastDims; font.pixelSize: 30 }
                    Lb { anchors.right: parent.right; anchors.rightMargin: 8; anchors.bottom: parent.bottom; text: Shot.lastWhat; px: 11 }
                }
                Item {
                    width: parent.width
                    height: keepChip.implicitHeight
                    Lb {
                        x: 8
                        anchors.verticalCenter: parent.verticalCenter
                        text: Shot.kept ? "saved · ~/pix/ss · click to edit" : "copied · click to edit"
                        px: 10
                        color: Theme.mute
                    }
                    Chip {
                        id: keepChip
                        anchors.right: parent.right
                        visible: !Shot.kept
                        text: "save"
                        filled: true
                        px: 10
                        onClicked: { Shot.keep(); stay.restart() }
                    }
                }
            }
            Rectangle { id: thumbMask; width: 328; height: 184; radius: 24; visible: false; layer.enabled: true }
            HoverHandler { id: cardHover }
        }

        // the flash fades in 0.9s, the card slides in from the right, stays a moment (while hovered too) and leaves the same way
        SequentialAnimation {
            id: fx
            PropertyAction { target: card; property: "t"; value: 0 }
            PropertyAction { target: fired; property: "visible"; value: true }
            ParallelAnimation {
                NumberAnimation { target: flash; property: "opacity"; from: 1; to: 0; duration: 900; easing.type: Easing.OutQuad }
                NumberAnimation { target: card; property: "t"; from: 0; to: 1; duration: Math.max(1, Theme.t); easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.glide }
            }
            ScriptAction { script: stay.restart() }
        }
        Timer {
            id: stay
            interval: 3000
            onTriggered: { if (cardHover.hovered) restart(); else out.restart() }
        }
        SequentialAnimation {
            id: out
            NumberAnimation { target: card; property: "t"; to: 0; duration: Math.max(1, Theme.t); easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.glide }
            PropertyAction { target: fired; property: "visible"; value: false }
        }
    }

    // ============ timer countdown: where the mode pill was; gone 150ms before the live capture (Shot.after) ============
    PanelWindow {
        screen: Shot.scr || Quickshell.screens[0]
        visible: Shot.countdown > 0
        anchors.bottom: true
        margins.bottom: 44
        implicitWidth: cd.width
        implicitHeight: cd.height
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        mask: Region {}                       // click-through
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        WlrLayershell.namespace: "aurora-shot-timer"

        Pill {
            id: cd
            pad: 22
            spacing: 14
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 10
                height: 10
                radius: 5
                color: Theme.live
            }
            Lb { anchors.verticalCenter: parent.verticalCenter; text: Shot.countWhat + " in"; color: Theme.fg }
            Num { anchors.verticalCenter: parent.verticalCenter; text: Shot.countdown; font.pixelSize: 36 }
            Lb { anchors.verticalCenter: parent.verticalCenter; text: "print to cancel"; px: 10 }
        }
    }

    // dotted line: a row or column of dots, 8px apart; an 8px thick line is exactly one row
    component Dots: Image {
        fillMode: Image.Tile
        horizontalAlignment: Image.AlignLeft
        verticalAlignment: Image.AlignTop
        source: "data:image/svg+xml," + encodeURIComponent('<svg xmlns="http://www.w3.org/2000/svg" width="8" height="8"><circle cx="4" cy="4" r="1.2" fill="#' + Theme.hex(Theme.fg) + '"/></svg>')
    }
}
