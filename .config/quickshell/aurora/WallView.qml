import QtQuick

// The wallpaper, drawn by shaders/wall.frag: look "dots" = a matrix of LED dots in the theme's tone (bg..fg),
// "colour" = dots in the image's own colours, "photo" = the plain image. A new path arrives as a wave from `origin`;
// two images take turns (the shown one and the incoming one), the old one is unloaded after the wave.
// An empty path = transparent (the dot grid shows through). `opaque` = the image covers everything.
// Ported from glyph-rice (github.com/Nebelung-cloud/glyph-rice, GPL-3.0), components/Wall.qml.
Item {
    id: root

    property string path
    property string look: Settings.wallLook
    property real pitch: Settings.wallPitch
    property real bright: Settings.wallBright / 100
    property point origin: Qt.point(width / 2, height / 2)
    property bool animate: Theme.motion
    readonly property bool opaque: fx.hasA > 0 && !run.running

    property bool flip: false            // which one is on screen: false = ia, true = ib
    readonly property Image cur: flip ? ib : ia
    readonly property Image next: flip ? ia : ib

    function crop(img) {
        var ia = img.implicitWidth / Math.max(1, img.implicitHeight), sa = width / Math.max(1, height)
        return ia > sa ? Qt.size(sa / ia, 1) : Qt.size(1, ia / sa)
    }
    function url(p) { return p ? "file://" + p.split("/").map(encodeURIComponent).join("/") : "" }

    // ---- change: shown = the path on screen, coming = the one loading ----
    property string shown: ""
    property string coming: ""
    property bool pending: false
    readonly property bool sized: width > 0 && height > 0   // no loading before the size is known (sourceSize 0 = full decode)

    onSizedChanged: change()
    onPathChanged: change()
    function change() {
        if (!sized) return
        if (run.running) { run.stop(); swap() }   // flipping faster than the wave: finish the current one now
        if (path === shown) { pending = false; next.source = ""; return }
        coming = path
        pending = true
        next.source = url(path)
        check()
    }
    function check() {
        if (!pending || next.status === Image.Loading) return
        pending = false                  // an error ends up transparent, like an empty path
        if (animate) run.restart()
        else swap()
    }
    function swap() {
        flip = !flip
        shown = coming
        fx.wave = 0
        next.source = ""                 // now the old one
    }

    NumberAnimation { id: run; target: fx; property: "wave"; from: 0; to: 1; duration: 1500; easing.type: Easing.InOutSine; onFinished: root.swap() }

    // the textures are siblings of the effect, not children, and opacity 0 rather than invisible: the scene graph
    // doesn't update the texture of an invisible Image. sourceSize is logical pixels; Qt multiplies by the DPR itself
    Image { id: ia; opacity: 0; asynchronous: true; cache: false; fillMode: Image.PreserveAspectCrop; sourceSize: Qt.size(root.width, root.height); onStatusChanged: if (root.next === ia) root.check() }
    Image { id: ib; opacity: 0; asynchronous: true; cache: false; fillMode: Image.PreserveAspectCrop; sourceSize: ia.sourceSize; onStatusChanged: if (root.next === ib) root.check() }

    ShaderEffect {
        id: fx
        anchors.fill: parent
        visible: hasA > 0 || hasB > 0 || run.running

        // ---- uniforms ----
        readonly property size size: Qt.size(width, height)
        readonly property point origin: root.origin
        readonly property var srcA: root.cur
        readonly property var srcB: root.next
        readonly property size cropA: root.crop(root.cur)
        readonly property size cropB: root.crop(root.next)
        readonly property real hasA: root.cur.status === Image.Ready ? 1 : 0
        readonly property real hasB: root.next.status === Image.Ready ? 1 : 0
        readonly property color lo: Theme.bg
        readonly property color hi: Theme.fg
        readonly property color bg: Theme.bg
        readonly property real pitch: root.pitch
        readonly property real bright: root.bright
        property real dots: root.look === "photo" ? 0 : 1
        property real mono: root.look === "dots" ? 1 : 0
        property real wave: 0
        Behavior on dots { enabled: Theme.motion; NumberAnimation { duration: 700; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.glide } }
        Behavior on mono { enabled: Theme.motion; NumberAnimation { duration: 700 } }

        fragmentShader: Qt.resolvedUrl("shaders/wall.frag.qsb")
    }
}
