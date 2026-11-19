import QtQuick
import QtQuick.Shapes
import qs.theme

// Pencere düzeni simgesi: dwindle, scrolling, monocle, master
Item {
    id: root

    property string layout: "dwindle"
    property real size: 14
    property color color: Colors.text
    property real strokeWidth: 2

    implicitWidth: size
    implicitHeight: size

    readonly property string mainPath: Icons.paths["layout-" + layout] ?? Icons.paths["layout-dwindle"]

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
            PathSvg { path: root.mainPath }
        }

        // scrolling: ekranın dışına taşan yan sütunlar soluk
        ShapePath {
            strokeColor: root.layout === "scrolling" ? Qt.rgba(root.color.r, root.color.g, root.color.b, 0.45) : "transparent"
            strokeWidth: root.strokeWidth
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin
            PathSvg { path: Icons.paths["layout-scrolling-sides"] }
        }
    }
}
