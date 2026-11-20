import QtQuick
import QtQuick.Layouts
import qs.theme
import qs.components
import qs.services
import qs.settings

// Ekran görüntüsü ve kaydı (Print): önizleme, kare hızı, imleç, ses, klasörler
SettingsPage {
    title: "Ekran görüntüsü"
    subtitle: "Print seçim ekranını açar; Shift+Print bütün ekranı çeker."

    SettingsSection {
        title: "Görüntü"

        StepperRow {
            title: "Köşedeki önizleme"
            subtitle: "Çekimden sonra sağ altta; tıklayınca düzenlenir"
            setting: "screenshot.previewSeconds"
            values: [0, 3, 6, 10, 15]
            format: v => v === 0 ? "Gösterme" : v + " sn"
        }
        ButtonRow {
            title: "Kayıt yeri"
            subtitle: Screenshot.shotsDir.replace(Screenshot.home, "~")
            buttonText: "Aç"
            buttonIcon: "folder"
            onClicked: Commands.run(["mkdir", "-p", Screenshot.shotsDir], () => Commands.open(["xdg-open", Screenshot.shotsDir]))
        }
    }

    SettingsSection {
        title: "Kayıt"

        ChoiceRow {
            title: "Kare hızı"
            setting: "screenshot.fps"
            options: [[30, "30"], [60, "60"]]
        }
        SwitchRow {
            title: "İmleç görünsün"
            setting: "screenshot.cursor"
        }
        SwitchRow {
            title: "Bilgisayarın sesi"
            subtitle: "Seçim ekranındaki ses düğmesi de bunu değiştirir"
            setting: "screenshot.audio"
        }
        ButtonRow {
            title: "Kayıt yeri"
            subtitle: Screenshot.recordingsDir.replace(Screenshot.home, "~")
            buttonText: "Aç"
            buttonIcon: "folder"
            onClicked: Commands.run(["mkdir", "-p", Screenshot.recordingsDir], () => Commands.open(["xdg-open", Screenshot.recordingsDir]))
        }
    }
}
