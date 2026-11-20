//@ pragma IconTheme Colloid-Dark
//@ pragma AppId desk-settings
// desk — giriş noktası
// Uygulama simgeleri Colloid temasından (home.nix → colloid-icon-theme). Tema kurulu değilse
// simgeler boş görünür; o zaman yukarıdaki satırı silmek Qt'nin ayarındaki temaya döner.
// AppId: desk'in tek normal penceresi Ayarlar; Hyprland, dock ve bar onu bu kimlikle tanır
// (nix/home.nix → desk-settings.desktop: "Ayarlar" adı ve simgesi; hypr/config/rules.lua).
import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.bar
import qs.modules.osd
import qs.modules.dock
import qs.modules.search
import qs.modules.wallpaper
import qs.modules.screenshot
import qs.modules.switcher
import qs.modules.settings
import qs.services

ShellRoot {
    // Ayarları Hyprland'e verir, pilde hafif görünüme geçer (services/Theming.qml); boşta kalma,
    // kapak ve pil koruma ayarlarını sisteme yazar (services/PowerSettings.qml)
    Component.onCompleted: {
        Theming.start();
        PowerSettings.start();
    }

    // Ayarlar penceresi: yalnızca açıkken var
    LazyLoader {
        active: Ui.settingsOpen

        SettingsWindow {}
    }

    // Her ekrana duvar kâğıdı, bar, dock, arama, duvar kâğıdı seçici, ses/parlaklık göstergesi,
    // ekran görüntüsü seçimi ve önizlemesi, pencere değiştirici
    Variants {
        model: Quickshell.screens

        Scope {
            id: perScreen
            required property var modelData

            WallpaperLayer {
                modelData: perScreen.modelData
            }
            Bar {
                modelData: perScreen.modelData
            }
            Dock {
                modelData: perScreen.modelData
            }
            Search {
                modelData: perScreen.modelData
            }
            WallpaperPicker {
                modelData: perScreen.modelData
            }
            Osd {
                modelData: perScreen.modelData
            }
            ScreenshotOverlay {
                modelData: perScreen.modelData
            }
            ShotPreview {
                modelData: perScreen.modelData
            }
            WindowSwitcher {
                modelData: perScreen.modelData
            }
        }
    }

    // Hyprland kısayolları buraya ulaşır (keybinds.lua):
    //   qs ipc -c desk call controlcenter toggle
    //   qs ipc -c desk call osd brightness
    IpcHandler {
        target: "controlcenter"

        function toggle(): void {
            Ui.controlCenterRequested("main");
        }
        // page: main, wifi, bluetooth, sound, battery, session
        function open(page: string): void {
            Ui.controlCenterRequested(page);
        }
    }

    // Super+Boşluk: qs ipc -c desk call search toggle
    // Super+V:      qs ipc -c desk call search clipboard
    IpcHandler {
        target: "search"

        function toggle(): void {
            Ui.searchRequested();
        }
        function clipboard(): void {
            Ui.clipboardRequested();
        }
    }

    // Super+W: qs ipc -c desk call wallpaper toggle
    IpcHandler {
        target: "wallpaper"

        function toggle(): void {
            Ui.wallpaperRequested();
        }
        // Seçici açmadan: qs ipc … call wallpaper set /yol/resim.jpg
        function set(path: string): void {
            Wallpaper.set(path);
        }
    }

    // qs ipc -c desk call notifications toggle
    IpcHandler {
        target: "notifications"

        function toggle(): void {
            Ui.notificationCenterRequested();
        }
        // Rahatsız etme: aç/kapa
        function dnd(): void {
            QuickSettings.setDoNotDisturb(!QuickSettings.doNotDisturb);
        }
    }

    // Print: qs ipc -c desk call screenshot start (kayıt sürüyorsa durdurur)
    // Shift+Print: … screenshot screen
    IpcHandler {
        target: "screenshot"

        function start(): void {
            Screenshot.start("");
        }
        function screen(): void {
            Screenshot.captureScreen();
        }
        function record(): void {
            Screenshot.start("record");
        }
        function stop(): void {
            Screenshot.stopRecording();
        }
    }

    // Alt+Tab (keybinds.lua): next ve "switcher" tuş takımı; orada Shift+Tab previous, Alt'ı bırakmak
    // commit, Esc cancel
    IpcHandler {
        target: "switcher"

        function next(): void {
            Switcher.next();
        }
        function previous(): void {
            Switcher.previous();
        }
        function commit(): void {
            Switcher.commit();
        }
        function cancel(): void {
            Switcher.cancel();
        }
    }

    // Super+Virgül: qs ipc -c desk call settings toggle
    // Aramadaki "Ayarlar" (desk-settings.desktop): … settings show
    IpcHandler {
        target: "settings"

        function toggle(): void {
            Ui.toggleSettings();
        }
        function show(): void {
            Ui.openSettings("");
        }
        // page: appearance, windows, bar, dock, notifications, display, power, input, screenshot,
        // shortcuts, about
        function open(page: string): void {
            Ui.openSettings(page);
        }
    }

    IpcHandler {
        target: "osd"

        function volume(): void {
            Ui.osdRequested("volume");
        }
        // Parlaklık değişince çekirdek haber vermiyor; değer yeniden okunur
        function brightness(): void {
            Brightness.refresh();
            Ui.osdRequested("brightness");
        }
    }
}
