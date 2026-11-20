import QtQuick
import qs.theme

// Yan yana seçenekler (macOS'taki "segmented control"): seçili olanın zemini kayarak gelir.
//   options: [[değer, "etiket"], …]   current: seçili değer   picked(değer)
Rectangle {
    id: root

    property var options: []
    property var current
    signal picked(var value)

    readonly property int currentIndex: options.findIndex(option => option[0] === current)
    readonly property Item currentItem: repeater.count > 0 && currentIndex >= 0 ? repeater.itemAt(currentIndex) : null

    implicitWidth: row.implicitWidth + 4
    implicitHeight: 28
    radius: 8
    color: Colors.segment

    Rectangle {
        visible: root.currentItem !== null
        x: (root.currentItem?.x ?? 0) + 2
        y: 2
        width: root.currentItem?.width ?? 0
        height: parent.height - 4
        radius: 6
        color: Colors.segmentSelected

        Behavior on x {
            NumberAnimation {
                duration: Metrics.durationNormal
                easing.type: Easing.OutCubic
            }
        }
        Behavior on width {
            NumberAnimation {
                duration: Metrics.durationNormal
                easing.type: Easing.OutCubic
            }
        }
    }

    Row {
        id: row
        x: 2
        y: 2

        Repeater {
            id: repeater
            model: root.options

            Item {
                id: segment

                required property var modelData
                required property int index
                readonly property bool selected: index === root.currentIndex

                width: label.implicitWidth + 24
                height: root.height - 4

                Text {
                    id: label
                    anchors.centerIn: parent
                    text: segment.modelData[1]
                    color: segment.selected || mouse.containsMouse ? Colors.text : Colors.textMuted
                    font.family: Typography.family
                    font.pixelSize: Typography.small + 1
                    font.weight: segment.selected ? Font.DemiBold : Font.Normal
                }
                MouseArea {
                    id: mouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.picked(segment.modelData[0])
                }
            }
        }
    }
}
