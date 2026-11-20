import QtQuick
import QtQuick.Layouts
import Quickshell.Services.UPower
import qs.theme
import qs.components
import qs.services
import qs.settings

// Pil ve güç: pil durumu ve koruma, güç modu, pilde hafif görünüm, boşta kalma süreleri, kapak.
// Süreler hypridle'a, kapak lid.sh'a gider (services/PowerSettings.qml).
SettingsPage {
    title: "Pil ve güç"

    readonly property var idleValues: [0, 1, 2, 3, 5, 10, 15, 20, 30, 45, 60, 90, 120]
    function minutes(v) {
        if (v <= 0)
            return "Hiçbir zaman";
        if (v < 60)
            return v + " dk";
        return v % 60 === 0 ? (v / 60) + " sa" : Math.floor(v / 60) + " sa " + (v % 60) + " dk";
    }

    SettingsSection {
        visible: BatteryStatus.present
        title: "Pil"

        ValueRow {
            title: "Durum"
            value: BatteryStatus.summary
        }
        ValueRow {
            visible: BatteryStatus.health > 0
            title: "Pil sağlığı"
            subtitle: "İlk günkü kapasitesine göre"
            value: "%" + Math.round(BatteryStatus.health)
        }
        SwitchRow {
            title: "Pil koruma"
            subtitle: PowerSettings.careError !== "" ? PowerSettings.careError : PowerSettings.careDetail
            enabled: PowerSettings.careSupported
            setting: "power.batteryCare"
        }
    }

    SettingsSection {
        title: "Güç"

        ChoiceRow {
            title: "Güç modu"
            subtitle: PowerMode.modes.find(m => m.profile === PowerMode.profile)?.detail ?? ""
            options: PowerMode.modes.filter(m => m.profile !== PowerProfile.Performance || PowerMode.hasPerformance).map(m => [m.profile, m.name])
            current: PowerMode.profile
            onPicked: value => PowerMode.set(value)
        }
        SwitchRow {
            visible: BatteryStatus.present
            title: "Pilde hafif görünüm"
            subtitle: "Prizden çıkınca ekran 60 Hz'e iner, bulanıklık ve animasyonlar hafifler"
            setting: "power.batteryLite"
        }
    }

    SettingsSection {
        visible: BatteryStatus.present
        title: "Boşta kalınca: pildeyken"

        StepperRow {
            title: "Ekranı karart"
            setting: "power.batteryDim"
            values: idleValues
            format: minutes
            labelWidth: 108
        }
        StepperRow {
            title: "Kilitle ve ekranı kapat"
            setting: "power.batteryLock"
            values: idleValues
            format: minutes
            labelWidth: 108
        }
        StepperRow {
            title: "Uyku"
            setting: "power.batterySuspend"
            values: idleValues
            format: minutes
            labelWidth: 108
        }
    }

    SettingsSection {
        title: BatteryStatus.present ? "Boşta kalınca: prizdeyken" : "Boşta kalınca"
        footer: "Müzik ya da video çalarken ekran kararmaz."

        StepperRow {
            title: "Ekranı karart"
            setting: "power.acDim"
            values: idleValues
            format: minutes
            labelWidth: 108
        }
        StepperRow {
            title: "Kilitle ve ekranı kapat"
            setting: "power.acLock"
            values: idleValues
            format: minutes
            labelWidth: 108
        }
        StepperRow {
            title: "Uyku"
            setting: "power.acSuspend"
            values: idleValues
            format: minutes
            labelWidth: 108
        }
    }

    SettingsSection {
        visible: BatteryStatus.present
        title: "Kapak"

        ChoiceRow {
            title: "Kapak kapanınca"
            setting: "power.lidAction"
            options: [["lock", "Kilitle"], ["suspend", "Uyu"]]
        }
        StepperRow {
            visible: Settings.s.power.lidAction === "lock"
            title: "Pildeyse sonra uyu"
            subtitle: "Kapak kapalı ve prize takılı değilken"
            setting: "power.lidSuspend"
            values: [0, 5, 10, 15, 30, 60]
            format: minutes
            labelWidth: 108
        }
    }
}
