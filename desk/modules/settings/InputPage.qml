import QtQuick
import QtQuick.Layouts
import qs.theme
import qs.components
import qs.services
import qs.settings

// Klavye ve fare: klavye düzenleri ve geçiş tuşu, tuş tekrarı, işaretçi, dokunmatik yüzey, odak.
// Hyprland'e services/Theming.qml verir (desk.apply_settings).
SettingsPage {
    title: "Klavye ve fare"

    readonly property var layouts: Settings.s.input.layouts

    function setLayout(id, on) {
        let list = layouts.filter(l => l !== id);
        if (on)
            list.push(id);
        // En az biri kalır; sıra listedeki sırayla (barda ilk düzen önce)
        list = Settings.keyboardLayouts.map(l => l.id).filter(l => list.includes(l));
        if (list.length > 0)
            Settings.set("input.layouts", list);
    }

    SettingsSection {
        title: "Klavye düzenleri"
        footer: layouts.length > 1 ? "Bardaki kısaltmaya bakarak hangisinde olduğunu görürsün." : "Birden çok düzen seçince aralarında kısayolla geçilir."

        Repeater {
            model: Settings.keyboardLayouts

            SwitchRow {
                required property var modelData
                readonly property bool on: layouts.includes(modelData.id)

                title: modelData.name
                checked: on
                // Son kalanı kapatılamaz
                enabled: !on || layouts.length > 1
                onToggled: value => setLayout(modelData.id, value)
            }
        }
        ChoiceRow {
            visible: layouts.length > 1
            title: "Düzen değiştir"
            setting: "input.layoutSwitch"
            options: [["grp:alt_shift_toggle", "Alt+Shift"], ["grp:ctrl_shift_toggle", "Ctrl+Shift"], ["grp:caps_toggle", "Caps Lock"]]
        }
    }

    SettingsSection {
        title: "Tuş tekrarı"

        SliderRow {
            title: "Hız"
            subtitle: "Basılı tutunca saniyede kaç kez"
            setting: "input.repeatRate"
            from: 10
            to: 80
            stepSize: 5
            format: v => v + "/sn"
        }
        SliderRow {
            title: "Gecikme"
            subtitle: "Tekrar başlamadan önce"
            setting: "input.repeatDelay"
            from: 150
            to: 800
            stepSize: 25
            format: v => v + " ms"
        }
    }

    SettingsSection {
        title: "Fare ve dokunmatik yüzey"

        SliderRow {
            title: "İşaretçi hızı"
            setting: "input.pointerSpeed"
            from: -1
            to: 1
            stepSize: 0.1
            format: v => v === 0 ? "Normal" : (v > 0 ? "+" : "−") + Math.round(Math.abs(v) * 100) + "%"
        }
        SwitchRow {
            title: "Odak fareyi izlesin"
            subtitle: "Fare hangi pencerenin üstündeyse o seçilir"
            setting: "input.followMouse"
        }
        SwitchRow {
            title: "Doğal kaydırma"
            subtitle: "Dokunmatik yüzeyde içerik parmağın yönünde kayar"
            setting: "input.naturalScroll"
        }
        SwitchRow {
            title: "Dokunarak tıkla"
            setting: "input.tapToClick"
        }
        SwitchRow {
            title: "Yazarken dokunmatik yüzeyi kapat"
            setting: "input.disableWhileTyping"
        }
    }
}
