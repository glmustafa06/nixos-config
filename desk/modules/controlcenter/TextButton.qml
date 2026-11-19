import QtQuick
import qs.theme

// Yazılı düğme. Türler: normal, vurgulu (accent), tehlikeli (danger: unut, sil gibi).
Rectangle {
    id: root

    property string text
    property bool accent: false
    property bool danger: false
    property bool enabled_: true

    signal clicked

    readonly property color foreground: accent ? Colors.accentForeground : danger ? Colors.danger : Colors.text

    implicitWidth: label.implicitWidth + 26
    implicitHeight: 32
    radius: 9
    opacity: enabled_ ? 1 : 0.45
    color: {
        if (accent)
            return mouse.containsMouse ? Colors.accentHover : Colors.accent;
        if (danger)
            return mouse.containsMouse ? Colors.dangerFillHover : Colors.dangerFill;
        return mouse.containsMouse ? Colors.buttonHover : Colors.button;
    }

    Text {
        id: label
        anchors.centerIn: parent
        text: root.text
        color: root.foreground
        font.family: Typography.family
        font.pixelSize: Typography.small
        font.weight: Font.DemiBold
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        enabled: root.enabled_
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
