pragma Singleton

import QtQuick
import Quickshell
import qs.settings

// Ölçüler: resimlerdeki köşe yarıçapları, boşluklar ve boyutlar.
// Bir değeri burada değiştirmek bütün shell'e yansır.
Singleton {
    // --- Üst bar
    readonly property int barHeight: 32
    readonly property int barPadding: 7      // barın sol ve sağ kenar boşluğu
    readonly property int barItemHeight: 24
    readonly property int barItemPadding: 9  // öğelerin iç yatay boşluğu
    readonly property int barItemSpacing: 1
    readonly property int barGroupGap: 6     // sağdaki simge grupları arasındaki ek boşluk
    readonly property int barIconSize: 16
    readonly property real barIconStroke: 2.1  // 24 birimlik ölçekte; bardaki bütün çizgi simgeler aynı kalınlıkta

    // Bar penceresi bardan uzun: ada açılınca bu alana taşar.
    // Saydam kısım tıklamaları engellemez (Bar.qml'deki mask).
    readonly property int barWindowHeight: 176

    // --- Ada (çentik)
    readonly property int islandWidth: 236
    readonly property int islandMusicWidth: 318    // müzik çalarken kapalı hâli
    readonly property int islandHeight: 32
    readonly property int islandRadius: 16
    readonly property int islandExpandedWidth: 600
    readonly property int islandExpandedHeight: 118
    readonly property int islandExpandedRadius: 34
    readonly property int islandNoticeWidth: 560      // bildirim gösterirken
    readonly property int islandNoticeHeight: 104
    readonly property int islandReplyHeight: 46       // yanıt yazarken eklenen satır
    // Ada açılıp kapanırken yay hareketi: sertlik büyüdükçe hızlanır,
    // sönüm büyüdükçe sekme azalır. Şu an ~0,1 sn'de %90, ~0,18 sn'de tamamen yerinde.
    readonly property real islandSpring: 12
    readonly property real islandDamping: 0.55
    readonly property int durationDot: Math.round(150 * motion)   // çalışma alanı noktası

    // --- Kontrol merkezi ve ses göstergesi (barın altında, sağda)
    readonly property int controlCenterWidth: 392
    readonly property int osdWidth: 336
    readonly property int popoutTop: 40      // ekranın üstünden (bar 32 + 8)
    readonly property int popoutRight: 10
    readonly property int sliderHeight: 28
    // Kilit ekranı. Kenarların koyulaşması ekran yüksekliğinin oranı olarak (contrast.py de okur)
    readonly property int lockMusicWidth: 400
    readonly property int lockFieldWidth: 280
    readonly property real lockUserTop: 0.70     // kişi ve şifre kutusunun başladığı yer
    readonly property real lockEdgeTop: 0.22     // üst koyulaşma burada biter
    readonly property real lockEdgeBottom: 0.50  // alt koyulaşma burada başlar
    // Duvar kâğıdı seçici (ekranın ortasında)
    readonly property int wallpaperPickerWidth: 880
    readonly property int wallpaperPickerHeight: 560
    readonly property int wallpaperColumns: 4
    // Bildirim merkezi en çok dock'un üstüne kadar uzar (fazlası kaydırılır)
    readonly property int notificationBottomGap: dockHeight + dockMargin * 2

    // --- Ayarlar penceresi
    readonly property int settingsWidth: 940
    readonly property int settingsHeight: 660
    readonly property int settingsSidebar: 224
    readonly property int settingsContentMax: 640   // içerik bundan genişse ortalanır
    readonly property int settingsRowHeight: 46
    readonly property int settingsRadius: 12        // kartlar

    // --- Menüler
    readonly property int menuRadius: 13
    readonly property int menuPadding: 6
    readonly property int menuItemHeight: 30
    readonly property int menuMinWidth: 220
    readonly property int menuOffset: 4    // bar ile menü arasındaki boşluk

    // --- Dock
    readonly property int dockIconSize: Math.max(32, Math.min(72, Settings.s.dock.iconSize)) // Ayarlar → Dock
    readonly property int dockPadding: 8      // simgelerle camın kenarı arası
    readonly property int dockSpacing: 6      // simgeler arası
    readonly property int dockSeparatorWidth: 13
    readonly property int switcherCell: 96     // pencere değiştiricide bir simgenin kutusu (simge %72'si)
    readonly property int dockRadius: 20
    readonly property int dockMargin: 8       // ekranın alt kenarıyla dock arası
    readonly property int dockHeight: dockIconSize + dockPadding * 2
    // Dock'un üstünde ad etiketi ve sağ tık menüsü için ayrılan yer (menü dock penceresinin içinde)
    readonly property int dockMenuSpace: 420
    // Dock penceresi: menü yeri + dock + alt boşluk (fazlası saydam ve tıklamaları geçirir)
    readonly property int dockWindowHeight: dockMenuSpace + dockHeight + dockMargin
    readonly property int dockHideDelay: 400  // pencere dock'a girince bu kadar bekleyip gizlenir
    readonly property int durationDock: Math.round(220 * motion)   // dock'un kayarak gizlenip çıkması

    // --- Arama
    readonly property int searchWidth: 640
    readonly property int searchBoxHeight: 56
    readonly property int searchRowHeight: 46
    readonly property int searchRadius: 18
    // Pencere en çok bu kadar uzun (8 sonuç); panel sonuç sayısına göre kısalır
    readonly property int searchRows: 8 // görünen en çok sonuç; fazlası kayar (pano)
    readonly property int searchWindowHeight: searchBoxHeight + searchRows * searchRowHeight + 24

    // --- Köşe yarıçapları
    readonly property int radiusSmall: 7   // bar öğesi, menü satırı
    readonly property int radiusWindow: 12 // pencereler (Hyprland'de de 12)
    readonly property int radiusTile: 16   // kontrol merkezi kutucukları, dock simgeleri
    readonly property int radiusPanel: 22  // paneller
    readonly property int radiusDock: 26

    // --- Boşluklar
    readonly property int gap: 10          // pencereler arası ve kenarlar
    readonly property int spacing: 8

    // --- Hareket süreleri (ms). Ayarlar → Görünüm → "Hareketi azalt" hepsini yarıya indirir.
    readonly property real motion: Settings.reduceMotion ? 0.5 : 1
    readonly property int durationFast: Math.round(120 * motion)
    readonly property int durationNormal: Math.round(200 * motion)
    readonly property int durationPage: Math.round(160 * motion)   // kontrol merkezinde sayfa geçişi
}
