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

    // Aramayı pano geçmişiyle aç (Super+V)
    signal clipboardRequested

    // Duvar kâğıdı seçiciyi aç/kapa (Super+W)
    signal wallpaperRequested

    // Aramayı aç/kapa (Super+Boşluk, bardaki logo ve büyüteç)
    signal searchRequested
}
