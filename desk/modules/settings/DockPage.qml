import QtQuick
import QtQuick.Layouts
import Quickshell.Widgets
import qs.theme
import qs.components
import qs.services
import qs.settings

// Dock: boyut, gizlenme, gösterilenler, sabitlenen uygulamalar
SettingsPage {
    title: "Dock"

    SettingsSection {
        SliderRow {
            title: "Simge boyu"
            setting: "dock.iconSize"
            from: 36
            to: 64
            stepSize: 2
            format: v => v + " px"
        }
        ChoiceRow {
            id: behavior
            title: "Gizlenme"
            subtitle: ({
                    smart: "Bir pencere dock'un yerine girince gizlenir; fare alt kenara gelince çıkar",
                    autohide: "Yalnızca fare ekranın alt kenarına gelince çıkar",
                    always: "Hep görünür; pencereler dock'un üstünde biter"
                })[Settings.s.dock.behavior] ?? ""
            setting: "dock.behavior"
            options: [["smart", "Akıllı"], ["autohide", "Hep gizli"], ["always", "Hep görünür"]]
        }
    }

    SettingsSection {
        title: "Göster"

        SwitchRow {
            title: "İndirilenler ve çöp kutusu"
            setting: "dock.places"
        }
        SwitchRow {
            title: "Bildirim rozetleri"
            subtitle: "Görülmemiş bildirimlerin sayısı, uygulamanın köşesinde"
            setting: "dock.badges"
        }
        SwitchRow {
            title: "Açık uygulamaların noktası"
            setting: "dock.indicators"
        }
    }

    SettingsSection {
        title: "Sabitlenenler"
        footer: "Sırayı dock'ta sürükleyerek değiştir. Açık bir uygulamayı tutmak için dock'ta sağ tıkla → Dock'ta tut."

        Repeater {
            model: DockApps.pinnedKeys

            OptionRow {
                required property string modelData

                title: DockApps.nameOf(modelData)
                leading: IconImage {
                    implicitSize: 26
                    source: DockApps.iconOf(modelData)
                }

                PillButton {
                    text: "Kaldır"
                    onClicked: DockApps.setPinned(modelData, false)
                }
            }
        }
        OptionRow {
            visible: DockApps.pinnedKeys.length === 0
            title: "Sabitlenmiş uygulama yok"
        }
    }
}
