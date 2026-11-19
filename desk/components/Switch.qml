import QtQuick
import qs.theme

// Aç/kapa anahtarı (Wi-Fi ve Bluetooth sayfalarının başında)
Item {
    id: root

    property bool checked: false
    signal toggled

    implicitWidth: 38
    implicitHeight: 22

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: root.checked ? Colors.accent : Colors.circleOff

        Behavior on color {
            ColorAnimation { duration: Metrics.durationFast }
        }
    }

    Rectangle {
        width: parent.height - 4
        height: width
        radius: width / 2
        y: 2
        x: root.checked ? parent.width - width - 2 : 2
        color: "white"

        Behavior on x {
            NumberAnimation {
                duration: Metrics.durationFast
                easing.type: Easing.OutCubic
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.toggled()
    }
}
