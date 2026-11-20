pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.settings

// Kontrol merkezindeki aç/kapa ayarları: rahatsız etme ve gece ışığı.
// Elle açılıp kapanmaları ~/.local/state/desk/settings.json dosyasında saklanır; oturum yeniden
// açılınca kaldığı yerden devam eder.
//
// Zamanlama (Ayarlar → Bildirimler, Ekran): her gün belli saatler arasında kendiliğinden açık.
// O saatlerde elle kapatılırsa zamanlamanın bitişine kadar kapalı kalır.
Singleton {
    id: root

    // ---------- Saat ----------
    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }
    readonly property int minuteOfDay: clock.date.getHours() * 60 + clock.date.getMinutes()
    readonly property real nowMs: clock.date.getTime()

    // from–to aralığında mı (gece yarısını aşabilir: 23:00–07:00)
    function inWindow(from, to, minute) {
        if (from === to)
            return false;
        return from < to ? minute >= from && minute < to : minute >= from || minute < to;
    }

    // Aralığın bu seferki bitişi (ms)
    function windowEnd(to) {
        const end = new Date(nowMs);
        end.setHours(Math.floor(to / 60), to % 60, 0, 0);
        if (end.getTime() <= nowMs)
            end.setDate(end.getDate() + 1);
        return end.getTime();
    }

    function formatMinute(minute) {
        const h = Math.floor(minute / 60), m = minute % 60;
        return String(h).padStart(2, "0") + ":" + String(m).padStart(2, "0");
    }

    // ---------- Rahatsız etme ----------
    readonly property var notificationSettings: Settings.s.notifications
    readonly property bool quietScheduled: notificationSettings.quietSchedule && inWindow(notificationSettings.quietFrom, notificationSettings.quietTo, minuteOfDay)
    // Bildirimler adada çıkmaz, merkezde birikir (Notifications.qml)
    readonly property bool doNotDisturb: (quietScheduled && nowMs >= store.quietSkipUntil) || store.doNotDisturb

    function setDoNotDisturb(on) {
        if (quietScheduled)
            store.quietSkipUntil = on ? 0 : windowEnd(notificationSettings.quietTo);
        store.doNotDisturb = on && !quietScheduled;
    }

    // ---------- Gece ışığı ----------
    readonly property var displaySettings: Settings.s.display
    readonly property bool nightScheduled: displaySettings.nightSchedule && inWindow(displaySettings.nightFrom, displaySettings.nightTo, minuteOfDay)
    readonly property bool nightLight: (nightScheduled && nowMs >= store.nightSkipUntil) || store.nightLight
    readonly property int nightLightTemperature: Math.max(2500, Math.min(6500, displaySettings.nightTemperature))

    function setNightLight(on) {
        if (nightScheduled)
            store.nightSkipUntil = on ? 0 : windowEnd(displaySettings.nightTo);
        store.nightLight = on && !nightScheduled;
    }

    // Gece ışığı: hyprsunset açık kaldığı sürece ekran sıcak renkte.
    // Süreç kapanınca (ışık kapatılınca ya da shell kapanınca) renkler eski hâline döner.
    // Sıcaklık değişince yeniden başlar (komut değişir).
    Process {
        id: sunset
        running: root.nightLight
        command: ["hyprsunset", "-t", String(root.nightLightTemperature)]
    }
    onNightLightTemperatureChanged: {
        if (sunset.running) {
            sunset.running = false;
            restartSunset.restart();
        }
    }
    Timer {
        id: restartSunset
        interval: 250
        onTriggered: sunset.running = Qt.binding(() => root.nightLight)
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
            // Zamanlama sürerken elle kapatıldı: bu zamana (ms) kadar kapalı
            property real quietSkipUntil: 0
            property real nightSkipUntil: 0
        }
    }
}
