import QtQuick
import QtQuick.Layouts
import qs.theme
import qs.components

// Başlık, açıklama ve aç/kapa anahtarı ("Otomatik bağlan" gibi)
RowLayout {
    id: root

    property string title
    property string subtitle
    property bool checked: false

    signal toggled

    spacing: 10

    ColumnLayout {
        Layout.fillWidth: true
        spacing: 1

        Text {
            Layout.fillWidth: true
            text: root.title
            color: Colors.text
            font.family: Typography.family
            font.pixelSize: Typography.body
            elide: Text.ElideRight
        }
        Text {
            Layout.fillWidth: true
            visible: text !== ""
            text: root.subtitle
            color: Colors.textMuted
            font.family: Typography.family
            font.pixelSize: Typography.small
            wrapMode: Text.WordWrap
        }
    }

    Switch {
        checked: root.checked
        onToggled: root.toggled()
    }
}
