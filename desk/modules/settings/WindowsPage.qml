import QtQuick
import qs.settings

// Pencereler: Hyprland'in boşlukları, köşeleri, gölgesi, karartması (services/Theming.qml →
// hypr/config/desk.lua → desk.apply_settings). Değişiklik pencerelere hemen yansır.
SettingsPage {
    title: "Pencereler"

    SettingsSection {
        title: "Boşluklar"

        SliderRow {
            title: "Pencereler arası"
            // Hyprland'de her pencerenin çevresi: iki pencere arası bunun iki katı
            from: 0
            to: 24
            stepSize: 2
            value: Settings.s.windows.gapsIn * 2
            format: v => v + " px"
            onMoved: v => Settings.set("windows.gapsIn", Math.round(v / 2))
        }
        SliderRow {
            title: "Ekran kenarına"
            setting: "windows.gapsOut"
            from: 0
            to: 32
            stepSize: 2
            format: v => v + " px"
        }
    }

    SettingsSection {
        title: "Görünüm"

        SliderRow {
            title: "Köşe yuvarlaklığı"
            subtitle: "Ekran görüntüsündeki pencere köşeleri de"
            setting: "windows.rounding"
            from: 0
            to: 20
            stepSize: 1
            format: v => v + " px"
        }
        SwitchRow {
            title: "Gölge"
            setting: "windows.shadow"
        }
        SwitchRow {
            title: "Odakta olmayanları karart"
            subtitle: "Hangi pencerenin seçili olduğu daha kolay görünür"
            setting: "windows.dimInactive"
        }
        SliderRow {
            visible: Settings.s.windows.dimInactive
            title: "Karartma"
            setting: "windows.dimStrength"
            from: 0.05
            to: 0.4
            stepSize: 0.05
            format: v => "%" + Math.round(v * 100)
        }
    }
}
