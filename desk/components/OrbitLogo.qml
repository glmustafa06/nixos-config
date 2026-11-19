import QtQuick
import QtQuick.Shapes
import qs.theme

// Logo: açık bir yörünge, merkezde gezegen, yörüngenin
// boşluğunda küçük bir uydu. 24 birimlik bir kutuda çizilip ölçeklenir.
Item {
    id: root

    property real size: 18
    property color color: Colors.accent

    implicitWidth: size
    implicitHeight: size

    Shape {
        width: 24
        height: 24
        scale: root.size / 24
        transformOrigin: Item.TopLeft
        preferredRendererType: Shape.CurveRenderer

        // Yörünge: -50°'den başlayıp saat yönünde 256° dönen yay
        ShapePath {
            strokeColor: root.color
            strokeWidth: 2.3
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap

            PathSvg {
                path: "M 17.464 5.489 A 8.5 8.5 0 1 1 4.360 8.274"
            }
        }

        // Gezegen
        ShapePath {
            strokeColor: "transparent"
            fillColor: root.color

            PathAngleArc {
                centerX: 12
                centerY: 12
                radiusX: 2.9
                radiusY: 2.9
                startAngle: 0
                sweepAngle: 360
            }
        }

        // Uydu: yörüngedeki boşluğun ortasında (258°)
        ShapePath {
            strokeColor: "transparent"
            fillColor: root.color

            PathAngleArc {
                centerX: 10.233
                centerY: 3.686
                radiusX: 1.55
                radiusY: 1.55
                startAngle: 0
                sweepAngle: 360
            }
        }
    }
}
