import QtQuick
import qs.theme

// Pil simgesi: dış çerçeve, doluluk ve uçtaki küçük tümsek.
// Şarj olurken dolgu vurgu renginde, %15'in altında turuncu.
Item {
    id: root

    property real level: 1 // 0..1
    property bool charging: false
    property color color: Colors.text
    property color accentColor: Colors.accent       // şarj olurken
    property color warningColor: Colors.microphone  // pil azken

    implicitWidth: 25
    implicitHeight: 13

    readonly property color fillColor: charging ? accentColor : level < 0.15 ? warningColor : color

    // Çerçeve
    Rectangle {
        x: 0.5
        y: 0.5
        width: 21.5
        height: 12
        radius: 3.6
        color: "transparent"
        border.width: 1.2
        border.color: Qt.rgba(root.color.r, root.color.g, root.color.b, 0.5)
    }

    // Doluluk
    Rectangle {
        x: 2.4
        y: 2.4
        width: Math.max(1.5, 17.7 * Math.min(Math.max(root.level, 0), 1))
        height: 8.2
        radius: 1.9
        color: root.fillColor

        Behavior on width {
            NumberAnimation { duration: Metrics.durationNormal }
        }
    }

    // Uç
    Rectangle {
        x: 22.9
        y: 4.4
        width: 1.7
        height: 4.2
        radius: 0.85
        color: Qt.rgba(root.color.r, root.color.g, root.color.b, 0.5)
    }
}
