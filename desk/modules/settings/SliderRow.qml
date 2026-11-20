import QtQuick
import qs.theme
import qs.settings

// Sürgü satırı; sağında değer ("48 px"):
//   SliderRow { title: "Simge boyu"; setting: "dock.iconSize"; from: 36; to: 64; stepSize: 2; format: v => v + " px" }
OptionRow {
    id: row

    property string setting
    property real from: 0
    property real to: 1
    property real stepSize: 0
    property real value: setting !== "" ? Number(Settings.get(setting)) : 0
    property var format: v => String(v)
    property int sliderWidth: 190
    signal moved(real value)

    Row {
        spacing: 12

        ThinSlider {
            anchors.verticalCenter: parent.verticalCenter
            width: row.sliderWidth
            from: row.from
            to: row.to
            stepSize: row.stepSize
            value: row.value
            onMoved: v => {
                if (row.setting !== "")
                    Settings.set(row.setting, v);
                row.moved(v);
            }
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            width: 58
            horizontalAlignment: Text.AlignRight
            text: row.format(row.value)
            color: Colors.textMuted
            font.family: Typography.family
            font.pixelSize: Typography.small + 1
            font.features: {
                "tnum": 1
            }
        }
    }
}
