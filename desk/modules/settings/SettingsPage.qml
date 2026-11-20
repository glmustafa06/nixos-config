import QtQuick
import QtQuick.Layouts
import qs.theme

// Ayarlar'ın bir sayfası: başlık ve altında kartlar, kaydırılır. İçerik geniş pencerede ortalanır.
//   SettingsPage { title: "Dock"; SettingsSection { … } }
Item {
    id: page

    property string title
    property string subtitle
    default property alias content: column.data
    // Kaydırılan alan (sayfa kendi içinde bir yere kaydırmak isterse)
    property alias flickable: flick

    Flickable {
        id: flick

        anchors.fill: parent
        contentWidth: width
        contentHeight: column.implicitHeight + 72
        boundsBehavior: Flickable.StopAtBounds
        clip: true

        ColumnLayout {
            id: column

            width: Math.min(flick.width - 64, Metrics.settingsContentMax)
            x: Math.round((flick.width - width) / 2)
            y: 30
            spacing: 22

            ColumnLayout {
                Layout.fillWidth: true
                Layout.bottomMargin: -4
                spacing: 4

                Text {
                    text: page.title
                    color: Colors.text
                    font.family: Typography.family
                    font.pixelSize: 24
                    font.weight: Font.Bold
                }
                Text {
                    Layout.fillWidth: true
                    visible: page.subtitle !== ""
                    text: page.subtitle
                    wrapMode: Text.Wrap
                    color: Colors.textMuted
                    font.family: Typography.family
                    font.pixelSize: Typography.body - 1
                }
            }
        }
    }

    // Kaydırma göstergesi (yalnızca içerik taşınca)
    Rectangle {
        visible: flick.contentHeight > flick.height + 1
        anchors.right: parent.right
        anchors.rightMargin: 3
        y: flick.visibleArea.yPosition * flick.height
        width: 4
        height: Math.max(24, flick.visibleArea.heightRatio * flick.height)
        radius: 2
        color: Colors.scrollIndicator
        opacity: flick.moving ? 1 : 0.5

        Behavior on opacity {
            NumberAnimation { duration: Metrics.durationNormal }
        }
    }
}
