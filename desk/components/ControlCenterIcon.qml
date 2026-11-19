import QtQuick
import QtQuick.Shapes
import qs.theme

// Kontrol merkezi simgesi: iki anahtar
Item {
    id: root

    property real size: 17
    property color color: Colors.text

    implicitWidth: size
    implicitHeight: size

    Shape {
        width: 24
        height: 24
        scale: root.size / 24
        transformOrigin: Item.TopLeft
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            strokeColor: root.color
            strokeWidth: 1.9
            fillColor: "transparent"
            PathSvg { path: Icons.paths["control-center"] }
        }
        ShapePath {
            strokeColor: "transparent"
            fillColor: root.color
            PathSvg { path: Icons.paths["control-center-knobs"] }
        }
    }
}
