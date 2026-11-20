import QtQuick
import qs.settings

// − değer + satırı:
//   StepperRow { title: "Kilitle"; setting: "power.batteryLock"; values: [0, 1, 5]; format: v => v + " dk" }
OptionRow {
    id: row

    property string setting
    property var values: []
    property var current: setting !== "" ? Settings.get(setting) : undefined
    property var format: v => String(v)
    property int labelWidth: 96
    signal picked(var value)

    Stepper {
        values: row.values
        current: row.current
        format: row.format
        labelWidth: row.labelWidth
        onPicked: value => {
            if (row.setting !== "")
                Settings.set(row.setting, value);
            row.picked(value);
        }
    }
}
