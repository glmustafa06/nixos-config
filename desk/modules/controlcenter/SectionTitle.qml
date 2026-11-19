import QtQuick
import QtQuick.Layouts
import qs.theme

// Sayfa içindeki küçük bölüm başlığı ("Cihazlarım", "Ayrıntılar" gibi)
Text {
    Layout.fillWidth: true
    Layout.leftMargin: 8
    Layout.topMargin: 4
    Layout.bottomMargin: 2
    color: Colors.textFaint
    font.family: Typography.family
    font.pixelSize: Typography.small
    font.weight: Font.DemiBold
}
