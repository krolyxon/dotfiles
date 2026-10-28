import QtQuick
import QtQuick.Shapes

// The halftone orb on an empty desktop (no wallpaper): equal dots, a radial gradient sets their brightness.
// phase (s) = a slow breath. Ported from glyph-rice (github.com/Nebelung-cloud/glyph-rice, GPL-3.0), components/Orb.qml.
Shape {
    property real phase: 0

    width: 1100
    height: 1100
    opacity: 0.18 + 0.06 * Math.sin(phase * 2 * Math.PI / 8)
    layer.enabled: true
    layer.textureSize: Qt.size(320, 320)   // a smooth gradient: the dots sample their cell centre, more pixels are wasted
    layer.effect: DotMask { step: 14 }

    ShapePath {
        strokeWidth: -1
        fillGradient: RadialGradient {
            centerX: 352; centerY: 330; centerRadius: 730
            focalX: 352; focalY: 330
            GradientStop { position: 0; color: Theme.fill }
            GradientStop { position: 1; color: Theme.fade(Theme.fill, 0) }
        }
        PathAngleArc { centerX: 550; centerY: 550; radiusX: 550; radiusY: 550; startAngle: 0; sweepAngle: 360 }
    }
}
