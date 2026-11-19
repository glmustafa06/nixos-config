import QtQuick
import QtQuick.Shapes
import qs.theme
import qs.services

// Wi-Fi simgesi: sinyal zayıfladıkça dış yaylar soluklaşır (macOS'taki gibi).
Item {
    id: root

    property real strength: 1 // 0..1
    property real size: 16
    property color color: Colors.text
    property real strokeWidth: 2.2

    // Kaç yay tam görünsün: 0–3 (Wi-Fi listesinin sıralamasıyla aynı eşikler)
    readonly property int bars: NetworkStatus.signalLevel(strength)

    implicitWidth: size
    implicitHeight: size

    function tone(level) {
        return bars >= level ? color : Qt.rgba(color.r, color.g, color.b, 0.3);
    }

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
            PathSvg { path: Icons.paths["wifi-dot"] }
        }
        ShapePath {
            strokeColor: root.tone(1)
            strokeWidth: root.strokeWidth
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            PathSvg { path: Icons.paths["wifi-arc1"] }
        }
        ShapePath {
            strokeColor: root.tone(2)
            strokeWidth: root.strokeWidth
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            PathSvg { path: Icons.paths["wifi-arc2"] }
        }
        ShapePath {
            strokeColor: root.tone(3)
            strokeWidth: root.strokeWidth
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            PathSvg { path: Icons.paths["wifi-arc3"] }
        }
    }
}
