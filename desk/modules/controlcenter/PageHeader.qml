import QtQuick
import QtQuick.Layouts
import qs.theme
import qs.components

// Ayrıntı sayfasının başı: geri oku, başlık, isteğe bağlı aç/kapa anahtarı
RowLayout {
    id: root

    property string title
    // Geri oku: sayfa başka bir sayfadan açıldıysa görünür (ControlCenter.canGoBack)
    property bool showBack: true
    property bool showSwitch: false
    property bool checked: false

    signal back
    signal toggled

    spacing: 8

    Rectangle {
        visible: root.showBack
        implicitWidth: 28
        implicitHeight: 28
        radius: 14
        color: backMouse.containsMouse ? Colors.hover : "transparent"

        Icon {
            anchors.centerIn: parent
            name: "chevron-left"
            size: 18
            strokeWidth: 2.4
        }

        MouseArea {
            id: backMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.back()
        }
    }

    Text {
        Layout.fillWidth: true
        Layout.leftMargin: root.showBack ? 0 : 6
        text: root.title
        color: Colors.text
        font.family: Typography.family
        font.pixelSize: Typography.title
        font.weight: Font.DemiBold
        elide: Text.ElideRight
    }

    Switch {
        visible: root.showSwitch
        checked: root.checked
        onToggled: root.toggled()
    }
}
