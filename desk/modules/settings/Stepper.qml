import QtQuick
import qs.theme
import qs.components

// − değer +  : bir listedeki değerler arasında adım adım (süreler, saatler)
//   values: [0, 5, 10]   current: 5   format: v => v + " dk"   picked(değer)
Row {
    id: root

    property var values: []
    property var current
    property var format: value => String(value)
    property int labelWidth: 96
    signal picked(var value)

    // Listede yoksa (elle yazılmış değer) en yakını
    readonly property int index: {
        const exact = values.indexOf(current);
        if (exact >= 0 || values.length === 0)
            return exact;
        let best = 0;
        values.forEach((v, i) => {
            if (Math.abs(v - current) < Math.abs(values[best] - current))
                best = i;
        });
        return best;
    }

    spacing: 4

    StepButton {
        icon: "minus"
        active: root.index > 0
        onClicked: root.picked(root.values[root.index - 1])
    }
    Text {
        width: root.labelWidth
        height: 26
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        text: root.format(root.current)
        color: Colors.text
        font.family: Typography.family
        font.pixelSize: Typography.small + 1
        font.weight: Font.DemiBold
        font.features: {
            "tnum": 1
        }
    }
    StepButton {
        icon: "plus"
        active: root.index < root.values.length - 1
        onClicked: root.picked(root.values[root.index + 1])
    }

    component StepButton: Rectangle {
        id: button

        property string icon
        property bool active: true
        signal clicked

        width: 26
        height: 26
        radius: 13
        color: mouse.containsMouse && active ? Colors.segmentSelected : Colors.segment
        opacity: active ? 1 : 0.4

        Icon {
            anchors.centerIn: parent
            name: button.icon
            size: 13
            strokeWidth: 2.4
            color: Colors.text
        }
        MouseArea {
            id: mouse
            anchors.fill: parent
            hoverEnabled: true
            enabled: button.active
            cursorShape: Qt.PointingHandCursor
            onClicked: button.clicked()
        }
    }
}
