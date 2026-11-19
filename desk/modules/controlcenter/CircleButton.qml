import QtQuick
import qs.theme
import qs.components

// Yuvarlak simge düğmesi. Açıkken vurgu renginde (Wi-Fi açık gibi).
Rectangle {
    id: root

    property string icon
    property bool on: false
    property real size: 34
    property real iconSize: 17

    signal clicked

    implicitWidth: size
    implicitHeight: size
    radius: size / 2
    color: on ? Colors.accent : mouse.containsMouse ? Colors.circleHover : Colors.circleOff

    Behavior on color {
        ColorAnimation { duration: Metrics.durationFast }
    }

    Icon {
        anchors.centerIn: parent
        name: root.icon
        size: root.iconSize
        strokeWidth: 2.3
        color: root.on ? Colors.accentForeground : Colors.circleOffIcon
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
