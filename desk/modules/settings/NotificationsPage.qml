import QtQuick
import QtQuick.Layouts
import Quickshell.Widgets
import qs.theme
import qs.components
import qs.services
import qs.settings

// Bildirimler: adadaki süre, rahatsız etme (zamanlı), uygulama başına gösterme, takvim hatırlatması
SettingsPage {
    title: "Bildirimler"

    readonly property var halfHours: Array.from({
        length: 48
    }, (_, i) => i * 30)

    SettingsSection {
        title: "Ada"

        StepperRow {
            title: "Adada kalma süresi"
            subtitle: "Fare üstündeyken kapanmaz"
            setting: "notifications.popupSeconds"
            values: [3, 5, 8, 12, 20]
            format: v => v + " sn"
        }
    }

    SettingsSection {
        title: "Rahatsız etme"
        footer: "Açıkken bildirimler adada çıkmaz, merkezde birikir. Zamanlama sürerken kontrol merkezinden kapatırsan bitişine kadar kapalı kalır."

        SwitchRow {
            title: "Rahatsız etme"
            subtitle: QuickSettings.quietScheduled ? "Şu an zamanlama sürüyor" : ""
            checked: QuickSettings.doNotDisturb
            onToggled: on => QuickSettings.setDoNotDisturb(on)
        }
        SwitchRow {
            title: "Her gün belli saatlerde"
            setting: "notifications.quietSchedule"
        }
        StepperRow {
            visible: Settings.s.notifications.quietSchedule
            title: "Başlangıç"
            setting: "notifications.quietFrom"
            values: halfHours
            format: QuickSettings.formatMinute
            labelWidth: 64
        }
        StepperRow {
            visible: Settings.s.notifications.quietSchedule
            title: "Bitiş"
            setting: "notifications.quietTo"
            values: halfHours
            format: QuickSettings.formatMinute
            labelWidth: 64
        }
    }

    SettingsSection {
        title: "Uygulamalar"
        footer: "Kapattığın uygulamaların bildirimleri adada çıkmaz, yalnızca bildirim merkezinde görünür."

        Repeater {
            model: Notifications.knownApps

            SwitchRow {
                required property string modelData
                readonly property string appKey: DockApps.keyForApp("", modelData)

                title: modelData
                checked: !Notifications.hiddenApps.includes(modelData)
                onToggled: on => Notifications.setAppShown(modelData, on)
                leading: Item {
                    implicitWidth: 24
                    implicitHeight: 24

                    IconImage {
                        anchors.fill: parent
                        visible: source != ""
                        source: appKey !== "" ? DockApps.iconOf(appKey) : ""
                    }
                    Icon {
                        anchors.centerIn: parent
                        visible: appKey === ""
                        name: modelData === "Takvim" ? "calendar" : modelData === "Pil" ? "battery-charging" : "bell"
                        size: 18
                        color: Colors.textMuted
                    }
                }
            }
        }
    }

    SettingsSection {
        title: "Takvim"

        ChoiceRow {
            title: "Yeni etkinlikte hatırlat"
            setting: "calendar.reminder"
            options: [[-1, "Yok"], [0, "Vaktinde"], [10, "10 dk"], [60, "1 sa"], [1440, "1 gün"]]
        }
    }
}
