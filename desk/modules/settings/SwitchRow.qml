import QtQuick
import qs.components
import qs.settings

// Aç/kapa satırı. setting verilirse Ayarlar'dan okur ve oraya yazar:
//   SwitchRow { title: "Rozetler"; setting: "dock.badges" }
// Yoksa checked bağlanır, toggled(açık) dinlenir.
OptionRow {
    id: row

    property string setting
    property bool checked: setting !== "" && Settings.get(setting) === true
    signal toggled(bool on)

    Switch {
        checked: row.checked
        onToggled: {
            const on = !row.checked;
            if (row.setting !== "")
                Settings.set(row.setting, on);
            row.toggled(on);
        }
    }
}
