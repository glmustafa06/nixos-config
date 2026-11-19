import QtQuick
import qs.theme

// Camın üst kenarındaki ince ışık: yüzeye derinlik verir, abartısız (macOS'taki gibi).
// Cam yüzeyin (köşeli Rectangle) içine konur: GlassEdge {}  — köşe yarıçapını yüzeyden alır.
// Yazıların altına girmez (yalnızca 1 piksellik kenar), okunabilirliği değiştirmez.
Item {
    id: root

    readonly property real radius: parent?.radius ?? 0

    anchors.fill: parent

    Rectangle {
        x: Math.max(root.radius * 0.6, 6)
        y: 1
        width: root.width - x * 2
        height: 1
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop {
                position: 0
                color: "transparent"
            }
            GradientStop {
                position: 0.5
                color: Colors.glassEdge
            }
            GradientStop {
                position: 1
                color: "transparent"
            }
        }
    }
}
