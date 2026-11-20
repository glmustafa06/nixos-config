import QtQuick
import qs.theme

// Bilgi satırı: solda ad, sağda değer (seçilip kopyalanabilir)
OptionRow {
    id: row

    property string value
    property bool mono: false

    TextEdit {
        width: Math.min(implicitWidth, row.width * 0.62)
        text: row.value
        readOnly: true
        selectByMouse: true
        wrapMode: TextEdit.Wrap
        horizontalAlignment: TextEdit.AlignRight
        color: Colors.textMuted
        selectionColor: Colors.accent
        selectedTextColor: Colors.accentForeground
        font.family: row.mono ? Typography.mono : Typography.family
        font.pixelSize: Typography.small + 1
    }
}
