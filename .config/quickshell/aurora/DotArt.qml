import QtQuick
import QtQuick.Shapes

// A track cover as LED dots in a circle; without a cover, the conical grey gradient from glyph's concept.
// Ported from glyph-rice (github.com/Nebelung-cloud/glyph-rice, GPL-3.0), components/Art.qml.
Item {
    id: root

    property string url
    property real step: 6

    layer.enabled: true
    layer.effect: DotMask { step: root.step; circle: true }

    Shape {
        anchors.fill: parent
        visible: img.status !== Image.Ready
        ShapePath {
            strokeWidth: -1
            fillGradient: ConicalGradient {
                centerX: root.width / 2; centerY: root.height / 2; angle: 50
                GradientStop { position: 0; color: Theme.fg }
                GradientStop { position: 0.2; color: Theme.mute }
                GradientStop { position: 0.4; color: Theme.fg }
                GradientStop { position: 0.6; color: Theme.s1 }
                GradientStop { position: 0.8; color: Theme.grey }
                GradientStop { position: 1; color: Theme.fg }
            }
            PathRectangle { width: root.width; height: root.height }
        }
    }
    Image {
        id: img
        anchors.fill: parent
        source: root.url
        fillMode: Image.PreserveAspectCrop
        sourceSize: Qt.size(256, 256)
        asynchronous: true
    }
}
