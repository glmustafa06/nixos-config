import QtQuick
import QtQuick.Layouts
import qs.theme

// Bardaki tıklanabilir öğe. Üstüne gelince ya da menüsü açıkken
// macOS'taki gibi hafif açık bir arka plan alır.
Item {
    id: root

    default property alias content: row.data
    property bool active: false
    property int padding: Metrics.barItemPadding
    readonly property alias hovered: mouse.containsMouse

    signal clicked
    signal pressed        // menü başlıkları basınca açılır (macOS gibi)
    signal rightClicked
    signal middleClicked
    // Tekerlek: her tam "çentik" için +1 (yukarı) ya da -1 (aşağı).
    // Dokunmatik yüzey çok küçük adımlar gönderdiği için adımlar biriktirilir;
    // yoksa iki parmakla hafif kaydırmak sesi bir anda sonuna kadar açardı.
    signal scrolled(int steps)

    property real _wheelBuffer: 0

    implicitWidth: row.implicitWidth + padding * 2
    implicitHeight: Metrics.barItemHeight
    opacity: enabled ? 1 : 0.42

    Rectangle {
        anchors.fill: parent
        radius: Metrics.radiusSmall
        color: root.active || mouse.containsMouse ? Colors.barHover : "transparent"

        Behavior on color {
            ColorAnimation { duration: Metrics.durationFast }
        }
    }

    RowLayout {
        id: row
        anchors.centerIn: parent
        spacing: 6
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        onPressed: event => {
            if (event.button === Qt.LeftButton)
                root.pressed();
        }
        onClicked: event => {
            if (event.button === Qt.RightButton)
                root.rightClicked();
            else if (event.button === Qt.MiddleButton)
                root.middleClicked();
            else
                root.clicked();
        }
        onWheel: wheel => {
            root._wheelBuffer += wheel.angleDelta.y;
            const steps = Math.trunc(root._wheelBuffer / 120); // 120 = bir fare tekerleği çentiği
            if (steps !== 0) {
                root._wheelBuffer -= steps * 120;
                root.scrolled(steps);
            }
        }
        onExited: root._wheelBuffer = 0
    }
}
