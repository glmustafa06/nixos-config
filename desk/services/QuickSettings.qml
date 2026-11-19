pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Kontrol merkezindeki aç/kapa ayarları: rahatsız etme ve gece ışığı.
// Durum ~/.local/state/desk/settings.json dosyasında saklanır; oturum yeniden
// açılınca kaldığı yerden devam eder.
Singleton {
    id: root

    readonly property bool doNotDisturb: store.doNotDisturb
    readonly property bool nightLight: store.nightLight
    readonly property int nightLightTemperature: store.nightLightTemperature

    // Rahatsız etme: bildirimler adada çıkmaz, merkezde birikir (Notifications.qml)
    function setDoNotDisturb(on) {
        store.doNotDisturb = on;
    }
    function setNightLight(on) {
        store.nightLight = on;
    }

    // Gece ışığı: hyprsunset açık kaldığı sürece ekran sıcak renkte.
    // Süreç kapanınca (ışık kapatılınca ya da shell kapanınca) renkler eski hâline döner.
    Process {
        running: root.nightLight
        command: ["hyprsunset", "-t", String(root.nightLightTemperature)]
    }

    FileView {
        id: file
        path: Quickshell.env("HOME") + "/.local/state/desk/settings.json"
        printErrors: false
        // Ayar değişince dosyaya yaz; dosya yoksa ilk yazışta oluşur
        onAdapterUpdated: writeAdapter()
        onLoadFailed: error => {
            if (error === FileViewError.FileNotFound)
                writeAdapter();
        }

        JsonAdapter {
            id: store

            property bool doNotDisturb: false
            property bool nightLight: false
            property int nightLightTemperature: 4500
        }
    }
}
