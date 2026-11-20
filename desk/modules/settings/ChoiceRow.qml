import QtQuick
import qs.settings

// Seçenekler satırı (yan yana düğmeler):
//   ChoiceRow { title: "Kare hızı"; setting: "screenshot.fps"; options: [[30, "30"], [60, "60"]] }
OptionRow {
    id: row

    property string setting
    property var options: []
    property var current: setting !== "" ? Settings.get(setting) : undefined
    signal picked(var value)

    Segmented {
        options: row.options
        current: row.current
        onPicked: value => {
            if (row.setting !== "")
                Settings.set(row.setting, value);
            row.picked(value);
        }
    }
}
