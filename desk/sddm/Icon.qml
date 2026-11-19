import QtQuick
import QtQuick.Shapes

// Çizgi simge (desk/components/Icon.qml'in giriş ekranındaki kopyası; yollar Lucide'dan, 24 birimlik)
Item {
    id: root

    property string name
    property real size: 16
    property color color: "white"
    property real strokeWidth: 2.2

    readonly property var paths: ({
            "chevron-right": "M9 18l6-6-6-6",
            "chevron-up": "M18 15l-6-6-6 6",
            "moon": "M12 3a6 6 0 0 0 9 9 9 9 0 1 1-9-9z",
            "power": "M12 2v10 M18.4 6.6a9 9 0 1 1-12.77.04",
            "rotate-ccw": "M3 12a9 9 0 1 0 9-9 9.75 9.75 0 0 0-6.74 2.74L3 8 M3 3v5h5",
            "monitor": "M4 3h16a2 2 0 0 1 2 2v10a2 2 0 0 1-2 2H4a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2z M8 21h8 M12 17v4",
            "check": "M20 6L9 17l-5-5"
        })

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
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin

            PathSvg {
                path: root.paths[root.name] ?? ""
            }
        }
    }
}
