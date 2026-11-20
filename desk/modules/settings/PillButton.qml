import QtQuick
import qs.theme
import qs.components

// Küçük yuvarlak köşeli düğme ("Değiştir…", "Sıfırla"). danger: kırmızı yazı (sıfırlama gibi).
Rectangle {
    id: root

    property string text
    property string icon
    property bool danger: false
    signal clicked

    implicitWidth: content.implicitWidth + 24
    implicitHeight: 28
    radius: 8
    color: danger ? (mouse.containsMouse ? Colors.dangerFillHover : Colors.dangerFill) : (mouse.containsMouse ? Colors.segmentSelected : Colors.circleOff)
    opacity: enabled ? 1 : 0.45

    Behavior on color {
        ColorAnimation { duration: Metrics.durationFast }
    }

    Row {
        id: content
        anchors.centerIn: parent
        spacing: 6

        Icon {
            visible: root.icon !== ""
            anchors.verticalCenter: parent.verticalCenter
            name: root.icon
            size: 14
            strokeWidth: 2.2
            color: root.danger ? Colors.danger : Colors.text
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.text
            color: root.danger ? Colors.danger : Colors.text
            font.family: Typography.family
            font.pixelSize: Typography.small + 1
            font.weight: Font.Medium
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
