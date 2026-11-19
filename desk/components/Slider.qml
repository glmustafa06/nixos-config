import QtQuick
import qs.theme

// macOS kontrol merkezindeki gibi kalın sürgü: dolu kısım açık renk, simge dolu kısmın içinde.
// Değer 0..1. Sürükleyince, tıklayınca ya da tekerlekle değişir; moved() ile bildirilir.
Item {
    id: root

    property real value: 0
    property string icon: ""
    // Tekerleğin bir çentiği ne kadar değiştirsin
    property real wheelStep: 0.05

    signal moved(real value)

    implicitHeight: Metrics.sliderHeight
    implicitWidth: 200

    function valueAt(x) {
        const usable = width - height;
        return Math.max(0, Math.min(1, (x - height / 2) / usable));
    }

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: Colors.sliderTrack
    }

    // Dolu kısım hiçbir zaman bir daireden küçük olmaz; simge hep görünür
    Rectangle {
        id: fill
        height: parent.height
        width: parent.height + (parent.width - parent.height) * Math.max(0, Math.min(1, root.value))
        radius: height / 2
        color: Colors.sliderFill

        // Tuşla ya da tekerlekle değişince kısa bir kayma; sürüklerken parmağı gecikmeden izler
        Behavior on width {
            enabled: !mouse.pressed
            NumberAnimation {
                duration: Metrics.durationFast
                easing.type: Easing.OutCubic
            }
        }

        Icon {
            anchors {
                left: parent.left
                leftMargin: 7
                verticalCenter: parent.verticalCenter
            }
            name: root.icon
            size: 15
            strokeWidth: 2.3
            color: Colors.sliderIcon
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        preventStealing: true
        onPressed: mouse => root.moved(root.valueAt(mouse.x))
        onPositionChanged: mouse => {
            if (pressed)
                root.moved(root.valueAt(mouse.x));
        }
        onWheel: wheel => {
            const steps = wheel.angleDelta.y / 120;
            root.moved(Math.max(0, Math.min(1, root.value + steps * root.wheelStep)));
        }
    }
}
