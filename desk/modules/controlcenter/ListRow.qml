import QtQuick
import QtQuick.Layouts
import qs.theme
import qs.components

// Ayrıntı sayfalarındaki liste satırı: [simge] başlık / alt yazı ……… sağ yazı [✓]
Rectangle {
    id: root

    property string icon
    property Component iconComponent: null   // simge yerine özel bir çizim (Wi-Fi gücü gibi)
    property string title
    property string subtitle
    property string trailing                 // sağdaki soluk yazı
    property string trailingIcon             // sağdaki küçük simge (şifreli ağda kilit gibi)
    property bool checked: false
    property bool active: false              // simge vurgu renginde (bağlı cihaz gibi)
    property bool selectable: true
    property bool showInfo: false            // sağda "ayrıntılar" düğmesi (ⓘ)

    signal clicked
    signal infoClicked

    implicitHeight: 44
    radius: 10
    color: mouse.containsMouse && selectable ? Colors.hover : "transparent"
    opacity: selectable ? 1 : 0.45

    // Satırın tıklaması; içerikten önce tanımlı ki ⓘ düğmesi kendi tıklamasını alsın
    MouseArea {
        id: mouse
        anchors.fill: parent
        enabled: root.selectable
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }

    RowLayout {
        anchors {
            fill: parent
            leftMargin: 8
            rightMargin: 10
        }
        spacing: 10

        // Simge yuvarlak zemin üstünde; etkinse vurgu renginde
        Rectangle {
            implicitWidth: 28
            implicitHeight: 28
            radius: 14
            color: root.active ? Colors.accent : Colors.circleOff

            // Özel çizim verilmişse o, yoksa adı verilen simge (yalnızca biri kurulur)
            Loader {
                anchors.centerIn: parent
                sourceComponent: root.iconComponent ?? defaultIcon
            }
            Component {
                id: defaultIcon
                Icon {
                    name: root.icon
                    size: 15
                    strokeWidth: 2.2
                    color: root.active ? Colors.accentForeground : Colors.circleOffIcon
                }
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0

            Text {
                Layout.fillWidth: true
                text: root.title
                color: Colors.text
                font.family: Typography.family
                font.pixelSize: Typography.body
                font.weight: Font.Medium
                elide: Text.ElideRight
            }
            Text {
                Layout.fillWidth: true
                visible: text !== ""
                text: root.subtitle
                color: Colors.textMuted
                font.family: Typography.family
                font.pixelSize: Typography.small
                elide: Text.ElideRight
            }
        }

        Text {
            visible: text !== ""
            text: root.trailing
            color: Colors.textFaint
            font.family: Typography.family
            font.pixelSize: Typography.small
        }

        Icon {
            visible: root.trailingIcon !== ""
            name: root.trailingIcon
            size: 13
            strokeWidth: 2.2
            color: Colors.textFaint
        }

        Icon {
            visible: root.checked
            name: "check"
            size: 16
            strokeWidth: 2.6
            color: Colors.accent
        }

        // Ayrıntılar düğmesi; satırın tıklamasından ayrı
        Rectangle {
            visible: root.showInfo
            implicitWidth: 26
            implicitHeight: 26
            radius: 13
            color: infoMouse.containsMouse ? Colors.circleHover : "transparent"

            Icon {
                anchors.centerIn: parent
                name: "info"
                size: 16
                strokeWidth: 2
                color: infoMouse.containsMouse ? Colors.text : Colors.textMuted
            }

            MouseArea {
                id: infoMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.infoClicked()
            }
        }
    }

}
