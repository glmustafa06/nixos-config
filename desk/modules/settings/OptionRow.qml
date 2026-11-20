import QtQuick
import QtQuick.Layouts
import qs.theme

// Ayar kartındaki satır: solda başlık ve açıklama, sağda denetim (anahtar, seçenekler, sürgü…).
// enabled: false iken soluk ve tıklanmaz.
Item {
    id: row

    property string title
    property string subtitle
    // Üstte ince çizgi: SettingsSection ayarlar (ilk görünen satırda yok)
    property bool topLine: false
    default property alias control: slot.data
    // Başlığın solunda (uygulama simgesi gibi)
    property alias leading: leadingSlot.data

    Layout.fillWidth: true
    implicitHeight: Math.max(Metrics.settingsRowHeight, texts.implicitHeight + 24, slot.implicitHeight + 18)
    opacity: enabled ? 1 : 0.45

    Rectangle {
        visible: row.topLine
        anchors {
            top: parent.top
            left: parent.left
            leftMargin: 14
            right: parent.right
        }
        height: 1
        color: Colors.settingsSeparator
    }

    Item {
        id: leadingSlot
        anchors {
            left: parent.left
            leftMargin: 14
            verticalCenter: parent.verticalCenter
        }
        width: childrenRect.width
        height: childrenRect.height
    }

    Column {
        id: texts

        anchors {
            left: leadingSlot.width > 0 ? leadingSlot.right : parent.left
            leftMargin: leadingSlot.width > 0 ? 10 : 14
            right: slot.left
            rightMargin: 16
            verticalCenter: parent.verticalCenter
        }
        spacing: 2

        Text {
            width: parent.width
            text: row.title
            elide: Text.ElideRight
            color: Colors.text
            font.family: Typography.family
            font.pixelSize: Typography.body
        }
        Text {
            width: parent.width
            visible: row.subtitle !== ""
            text: row.subtitle
            wrapMode: Text.Wrap
            color: Colors.textMuted
            font.family: Typography.family
            font.pixelSize: Typography.small
        }
    }

    Item {
        id: slot
        anchors {
            right: parent.right
            rightMargin: 14
            verticalCenter: parent.verticalCenter
        }
        implicitWidth: childrenRect.width
        implicitHeight: childrenRect.height
        width: implicitWidth
        height: implicitHeight
    }
}
