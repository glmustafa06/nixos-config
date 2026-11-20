import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import qs.theme
import qs.components
import qs.services
import qs.settings

// Ekran: parlaklık, gece ışığı (zamanlı), ekranların bilgisi
SettingsPage {
    title: "Ekran"

    readonly property var halfHours: Array.from({
        length: 48
    }, (_, i) => i * 30)

    SettingsSection {
        visible: Brightness.available

        SliderRow {
            title: "Parlaklık"
            from: 0
            to: 1
            stepSize: 0.01
            value: Brightness.level
            format: v => "%" + Math.round(v * 100)
            onMoved: v => Brightness.set(v)
        }
    }

    SettingsSection {
        title: "Gece ışığı"
        footer: "Ekranın rengini akşamları sıcaklaştırır, göz daha az yorulur."

        SwitchRow {
            title: "Gece ışığı"
            subtitle: QuickSettings.nightScheduled ? "Şu an zamanlama sürüyor" : ""
            checked: QuickSettings.nightLight
            onToggled: on => QuickSettings.setNightLight(on)
        }
        SliderRow {
            title: "Sıcaklık"
            subtitle: "Düşük değer daha sarı"
            setting: "display.nightTemperature"
            from: 3000
            to: 6000
            stepSize: 100
            format: v => v + " K"
        }
        SwitchRow {
            title: "Her gün belli saatlerde"
            setting: "display.nightSchedule"
        }
        StepperRow {
            visible: Settings.s.display.nightSchedule
            title: "Başlangıç"
            setting: "display.nightFrom"
            values: halfHours
            format: QuickSettings.formatMinute
            labelWidth: 64
        }
        StepperRow {
            visible: Settings.s.display.nightSchedule
            title: "Bitiş"
            setting: "display.nightTo"
            values: halfHours
            format: QuickSettings.formatMinute
            labelWidth: 64
        }
    }

    // Bağlı ekranlar (yalnızca bilgi; ölçek ve çözünürlük hypr/config/monitors.lua'da)
    SettingsSection {
        title: Hyprland.monitors.values.length > 1 ? "Ekranlar" : "Ekran"
        footer: "Çözünürlük ve ölçek nixos-config/hypr/config/monitors.lua'da. Pildeyken 60 Hz'e iner (Pil ve güç)."

        Repeater {
            model: Hyprland.monitors.values

            ValueRow {
                required property var modelData
                readonly property var info: modelData.lastIpcObject ?? {}

                title: modelData.name + (info.model ? "  ·  " + info.model : "")
                value: info.width ? `${info.width} × ${info.height}, ${Math.round(info.refreshRate ?? 60)} Hz, ölçek ${Number(info.scale ?? 1).toLocaleString(Qt.locale("tr_TR"), "f", (info.scale ?? 1) % 1 === 0 ? 0 : 2)}` : ""
            }
        }
    }
}
