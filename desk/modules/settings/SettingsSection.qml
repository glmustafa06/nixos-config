import QtQuick
import QtQuick.Layouts
import qs.theme

// Başlıklı ayar kartı. İçindeki satırların (OptionRow) arasına ince çizgi kendiliğinden girer;
// gizli satırlar atlanır.
//   SettingsSection { title: "Saat"; SwitchRow { … } SwitchRow { … } }
ColumnLayout {
    id: section

    property string title
    property string footer   // kartın altındaki açıklama
    default property alias rows: column.data

    Layout.fillWidth: true
    spacing: 7

    Text {
        Layout.leftMargin: 4
        visible: section.title !== ""
        text: section.title
        color: Colors.textFaint
        font.family: Typography.family
        font.pixelSize: Typography.small
        font.weight: Font.DemiBold
    }

    Rectangle {
        Layout.fillWidth: true
        implicitHeight: column.implicitHeight
        radius: Metrics.settingsRadius
        color: Colors.settingsCard
        border.width: 1
        border.color: Colors.settingsCardBorder

        ColumnLayout {
            id: column

            width: parent.width
            spacing: 0
            onVisibleChildrenChanged: Qt.callLater(section.relayout)
        }
    }

    Text {
        Layout.fillWidth: true
        Layout.leftMargin: 4
        Layout.rightMargin: 4
        visible: section.footer !== ""
        text: section.footer
        wrapMode: Text.Wrap
        color: Colors.textFaint
        font.family: Typography.family
        font.pixelSize: Typography.small
    }

    // İlk görünen satırın üstünde çizgi olmaz
    function relayout() {
        let first = true;
        for (const child of column.children) {
            if (child.topLine === undefined)
                continue;
            child.topLine = child.visible && !first;
            if (child.visible)
                first = false;
        }
    }

    Component.onCompleted: Qt.callLater(relayout)
}
