pragma Singleton

import QtQuick
import Quickshell

// Shell'in parçaları arasındaki ortak durum ve istekler.
// Kısayollar (IPC, shell.qml) buradan barı ve göstergeyi tetikler.
Singleton {
    id: root

    // Kontrol merkezi açık mı (açıkken ses göstergesi çıkmaz, sürgüler zaten görünüyor)
    property bool controlCenterOpen: false
    // Bildirim merkezi açık mı (açıkken ses göstergesi çıkmaz; ikisi aynı köşede)
    property bool notificationCenterOpen: false

    // Kontrol merkezini aç/kapa. page: "main", "wifi", "bluetooth" …
    signal controlCenterRequested(string page)
    // Kontrol merkezini o sayfada aç; zaten oradaysa dokunma (Bluetooth eşleşme sorusu gibi)
    signal controlCenterOpenRequested(string page)

    // Ses ya da parlaklık göstergesini göster. kind: "volume" ya da "brightness"
    signal osdRequested(string kind)

    // Bildirim merkezini aç/kapa (saate tıklamakla aynı)
    signal notificationCenterRequested
    // Bildirim merkezini aç (açıksa kapatma) ve takvimde o günü göster. day: "2026-11-24"
    // (takvim hatırlatmasına tıklanınca)
    signal calendarRequested(string day)

    // Aramayı pano geçmişiyle aç (Super+V)
    signal clipboardRequested

    // Duvar kâğıdı seçiciyi aç/kapa (Super+W)
    signal wallpaperRequested

    // Aramayı aç/kapa (Super+Boşluk, bardaki logo ve büyüteç)
    signal searchRequested

    // Ayarlar penceresi (Super+Virgül, kontrol merkezindeki çark, aramada "Ayarlar").
    // page: appearance, windows, bar, dock, notifications, display, power, input, screenshot,
    // shortcuts, about ("" en son açılan)
    property bool settingsOpen: false
    property string settingsPage: "appearance"
    // Pencere zaten açıkken tekrar istenince öne gelsin diye artar
    property int settingsRaise: 0

    function openSettings(page) {
        if (page)
            settingsPage = page;
        if (settingsOpen)
            settingsRaise++;
        settingsOpen = true;
    }
    function toggleSettings() {
        settingsOpen = !settingsOpen;
    }
}
