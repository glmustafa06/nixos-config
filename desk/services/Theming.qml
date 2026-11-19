pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.UPower

// Hyprland'e çalışırken verilen görünüm ayarı (nixos-config/hypr/config/desk.lua):
// pilde hafif görünüm: ekran 60 Hz, bulanıklık tek geçiş, animasyonlar %20 kısa.
// hyprctl reload bunu dosyadakine döndürür; "configreloaded" olayında yeniden verilir.
// kitty ve Dolphin'in renkleri ayrı: scripts/apps_theme.py (colors.sh çağırır).
Singleton {
    id: root

    // UPower doğrudan: dizüstünde fiş çekili mi (masaüstünde hep false)
    readonly property bool battery: BatteryStatus.present && UPower.onBattery
    // Hyprland'e en son hangisi verildi (dosyadaki ayar prizdekidir)
    property bool batteryApplied: false

    function start() {
        // UPower hazır olsun diye kısa bir bekleme
        powerTimer.restart();
    }

    function hyprEval(code) {
        Commands.run(["hyprctl", "eval", code], (exit, out) => {
            if (exit !== 0 || out.trim() !== "ok")
                console.warn(`Theming: hyprctl eval '${code}' → ${out.trim()}`);
        });
    }

    function applyPower() {
        if (battery === batteryApplied)
            return;
        batteryApplied = battery;
        hyprEval(`desk.set_power(${battery})`);
    }

    onBatteryChanged: powerTimer.restart()

    // Priz takılıp çıkarılırken ekran art arda kip değiştirmesin
    Timer {
        id: powerTimer
        interval: 3000
        onTriggered: root.applyPower()
    }

    Connections {
        target: Hyprland

        function onRawEvent(event) {
            if (event.name !== "configreloaded")
                return;
            root.batteryApplied = false;
            reapply.restart();
        }
    }
    Timer {
        id: reapply
        interval: 500
        onTriggered: root.applyPower()
    }
}
