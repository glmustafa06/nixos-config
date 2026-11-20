import QtQuick
import qs.theme

// İnce sürgü: vurgu renginde dolan iz ve beyaz düğme. Sürüklerken ve tıklayınca moved(değer).
Item {
    id: root

    property real from: 0
    property real to: 1
    property real stepSize: 0
    property real value: 0
    signal moved(real value)

    readonly property real ratio: to > from ? Math.max(0, Math.min(1, (value - from) / (to - from))) : 0
    readonly property real knobSize: 18

    implicitWidth: 200
    implicitHeight: 22

    Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width
        height: 4
        radius: 2
        color: Colors.sliderTrackThin

        Rectangle {
            width: knob.x + knob.width / 2
            height: parent.height
            radius: 2
            color: Colors.accent
        }
    }

    Rectangle {
        id: knob
        anchors.verticalCenter: parent.verticalCenter
        x: root.ratio * (root.width - width)
        width: root.knobSize
        height: root.knobSize
        radius: width / 2
        color: Colors.sliderKnob
        border.width: 1
        border.color: Colors.dragShadow
        scale: area.pressed ? 1.08 : 1

        Behavior on scale {
            NumberAnimation { duration: Metrics.durationFast }
        }
    }

    MouseArea {
        id: area
        anchors.fill: parent
        anchors.margins: -4
        preventStealing: true
        cursorShape: Qt.PointingHandCursor
        onPressed: mouse => root.setFrom(mouse.x - 4)
        onPositionChanged: mouse => {
            if (pressed)
                root.setFrom(mouse.x - 4);
        }
    }

    function setFrom(x) {
        const usable = width - knobSize;
        const r = usable > 0 ? (x - knobSize / 2) / usable : 0;
        emit(from + Math.max(0, Math.min(1, r)) * (to - from));
    }

    function emit(raw) {
        let v = Math.max(from, Math.min(to, raw));
        if (stepSize > 0)
            v = from + Math.round((v - from) / stepSize) * stepSize;
        // Kayan nokta artığı (0.15000000002) dosyaya yazılmasın
        v = Math.round(v * 1000) / 1000;
        if (v !== value)
            moved(v);
    }
}
