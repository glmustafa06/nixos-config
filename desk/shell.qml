//@ pragma IconTheme Colloid-Dark
// desk — giriş noktası
// Uygulama simgeleri Colloid temasından (home.nix → colloid-icon-theme). Tema kurulu değilse
// simgeler boş görünür; o zaman yukarıdaki satırı silmek Qt'nin ayarındaki temaya döner.
import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.bar
import qs.modules.osd
import qs.modules.dock
import qs.modules.search
import qs.modules.wallpaper
import qs.services

ShellRoot {
    // Pilde hafif görünüm: Hyprland'e söyler (services/Theming.qml)
    Component.onCompleted: Theming.start()

    // Her ekrana duvar kâğıdı, bar, dock, arama, duvar kâğıdı seçici ve ses/parlaklık göstergesi
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
