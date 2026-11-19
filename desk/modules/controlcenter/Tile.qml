import QtQuick
import qs.theme

// Kontrol merkezindeki yarı saydam kutu. İçeriği kendisi yerleştirir (padding).
// Tıklanabilir yapılırsa üstüne gelince biraz aydınlanır.
Rectangle {
    id: root

    default property alias content: inner.data
    property int padding: 12
    property bool clickable: false
    property bool highlighted: false   // "açık" durumu: vurgu renginde

    signal clicked

    // Boyut içindeki (ilk) öğenin doğal boyutundan gelir
    readonly property Item contentItem: inner.children.length > 0 ? inner.children[0] : null
    implicitWidth: (contentItem?.implicitWidth ?? 0) + padding * 2
    implicitHeight: (contentItem?.implicitHeight ?? 0) + padding * 2
    radius: 16
    color: highlighted ? Colors.accent : mouse.containsMouse && clickable ? Colors.tileHover : Colors.tile
    border.width: 1
    border.color: Colors.tileBorder

    Behavior on color {
        ColorAnimation { duration: Metrics.durationFast }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        enabled: root.clickable
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }

    Item {
        id: inner
        anchors {
            fill: parent
            margins: root.padding
        }
    }
}
