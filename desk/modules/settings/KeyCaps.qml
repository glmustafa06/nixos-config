import QtQuick
import qs.theme

// Bir kısayol: tuşlar yan yana küçük kutularda ("Super" "Shift" "Q")
Row {
    id: root

    property var keys: []

    spacing: 3

    Repeater {
        model: root.keys

        Rectangle {
            required property string modelData

            width: Math.max(22, label.implicitWidth + 12)
            height: 22
            radius: 5
            color: Colors.keyCap
            border.width: 1
            border.color: Colors.keyCapBorder

            Text {
                id: label
                anchors.centerIn: parent
                text: parent.modelData
                color: Colors.text
                font.family: Typography.family
                font.pixelSize: Typography.small
                font.weight: Font.Medium
            }
        }
    }
}
