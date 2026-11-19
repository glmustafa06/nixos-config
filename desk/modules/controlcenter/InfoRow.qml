import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.theme
import qs.components

// "IP adresi ……… 192.168.1.34 [kopyala]" satırı (ayrıntı sayfaları)
RowLayout {
    id: root

    property string label
    property string value
    property bool copyable: false

    spacing: 8

    Text {
        text: root.label
        color: Colors.textMuted
        font.family: Typography.family
        font.pixelSize: Typography.small
    }

    Text {
        Layout.fillWidth: true
        horizontalAlignment: Text.AlignRight
        text: root.value === "" ? "—" : root.value
        color: Colors.text
        font.family: Typography.family
        font.pixelSize: Typography.small
        font.features: {
            "tnum": 1
        }
        elide: Text.ElideLeft
    }

    // Panoya kopyala (MAC ya da IP adresi gibi)
    Rectangle {
        visible: root.copyable && root.value !== ""
        implicitWidth: 22
        implicitHeight: 22
        radius: 6
        color: copyMouse.containsMouse ? Colors.hover : "transparent"

        Icon {
            id: copyIcon
            anchors.centerIn: parent
            name: copied.running ? "check" : "copy"
            size: 13
            strokeWidth: 2.2
            color: copied.running ? Colors.accent : Colors.textMuted
        }

        Timer {
            id: copied
            interval: 1200
        }

        MouseArea {
            id: copyMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                Quickshell.execDetached(["wl-copy", root.value]);
                copied.restart();
            }
        }
    }
}
