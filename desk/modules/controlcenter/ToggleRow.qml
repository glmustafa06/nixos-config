import QtQuick
import QtQuick.Layouts
import qs.theme

// Yuvarlak düğme + başlık + durum yazısı ("Wi-Fi / Ev_5G" gibi).
// Düğmeye tıklamak aç/kapa yapar, satırın geri kalanı ayrıntı sayfasını açar.
Item {
    id: root

    property string icon
    property bool on: false
    property string title
    property string subtitle

    signal toggled
    signal opened

    implicitWidth: row.implicitWidth
    implicitHeight: row.implicitHeight

    // Düğmenin altında kalır; düğme kendi tıklamasını alır
    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.opened()
    }

    RowLayout {
        id: row
        anchors.fill: parent
        spacing: 10

        CircleButton {
            icon: root.icon
            on: root.on
            onClicked: root.toggled()
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 1

            Text {
                Layout.fillWidth: true
                text: root.title
                color: Colors.text
                font.family: Typography.family
                font.pixelSize: Typography.body
                font.weight: Font.DemiBold
                elide: Text.ElideRight
            }
            Text {
                Layout.fillWidth: true
                text: root.subtitle
                color: Colors.textMuted
                font.family: Typography.family
                font.pixelSize: Typography.small
                elide: Text.ElideRight
            }
        }
    }
}
