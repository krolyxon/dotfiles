import QtQuick

// Dot-matrix mask for layer.effect: `layer.enabled: true; layer.effect: DotMask { step: 4 }`.
// The item becomes evenly sized grey LED dots (luminance only). Album covers, app icons, the halftone orb.
// Ported from glyph-rice (github.com/Nebelung-cloud/glyph-rice, GPL-3.0), components/Dm.qml.
ShaderEffect {
    property real step: 5
    readonly property real pitch: step   // the shader's uniform: "step" is a GLSL builtin
    property bool circle: false          // only the dots inside the inscribed circle
    readonly property real circ: circle ? 1 : 0
    readonly property size size: Qt.size(width, height)
    fragmentShader: Qt.resolvedUrl("shaders/dots.frag.qsb")
}
