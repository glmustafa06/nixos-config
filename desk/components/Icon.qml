import QtQuick
import QtQuick.Shapes
import qs.theme

// Çizgi simge. Kullanım: Icon { name: "search"; size: 16 }
// İsimler theme/Icons.qml'de. Çizgi kalınlığı 24 birimlik ölçekte verilir.
Item {
    id: root

    property string name
    property real size: 16
    property color color: Colors.text
    property real strokeWidth: 2.2
    property color fill: "transparent"

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
            strokeWidth: root.strokeWidth
            fillColor: root.fill
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin

            PathSvg {
                path: Icons.paths[root.name] ?? ""
            }
        }
    }
}
