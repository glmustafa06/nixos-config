pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.UPower
import qs.settings

// Hyprland'e çalışırken verilen ayarlar (nixos-config/hypr/config/desk.lua):
//  - pilde hafif görünüm: ekran 60 Hz, bulanıklık tek geçiş, animasyonlar %20 kısa
//    (Ayarlar → Pil ve güç'te kapatılabilir)
//  - Ayarlar penceresindekiler: pencere boşlukları, köşeler, karartma, gölge, animasyonlar,
//    klavye düzenleri, dokunmatik yüzey … (desk.apply_settings)
// hyprctl reload bunları dosyadakine döndürür; "configreloaded" olayında yeniden verilir.
// kitty ve Dolphin'in renkleri ayrı: scripts/apps_theme.py (colors.sh çağırır; vurgu rengi
// Ayarlar'dan değişince de burası çağırır).
Singleton {
    id: root

    // UPower doğrudan: dizüstünde fiş çekili mi (masaüstünde hep false)
    readonly property bool battery: BatteryStatus.present && UPower.onBattery
    readonly property bool lite: battery && Settings.s.power.batteryLite
    // Hyprland'e en son hangisi verildi (dosyadaki ayar prizdekidir); null: henüz verilmedi
    property var liteApplied: null

    function start() {
        // UPower hazır olsun diye kısa bir bekleme
        powerTimer.restart();
        applySettings();
    }

    function hyprEval(code) {
        Commands.run(["hyprctl", "eval", code], (exit, out) => {
            if (exit !== 0 || out.trim() !== "ok")
                console.warn(`Theming: hyprctl eval '${code}' → ${out.trim()}`);
        });
    }

    function applyPower() {
        if (lite === liteApplied)
            return;
        liteApplied = lite;
        hyprEval(`desk.set_power(${lite})`);
    }

    onLiteChanged: powerTimer.restart()

    // Priz takılıp çıkarılırken ekran art arda kip değiştirmesin
    Timer {
        id: powerTimer
        interval: 3000
        onTriggered: root.applyPower()
    }

    // ---------- Ayarlar → Hyprland ----------
    // desk.lua'daki desk.apply_settings bu tabloyu alır (adlar Hyprland'deki gibi)
    readonly property var hyprSettings: {
        const w = Settings.s.windows;
        const i = Settings.s.input;
        const layouts = i.layouts.map(id => Settings.keyboardLayouts.find(l => l.id === id)).filter(l => l !== undefined);
        if (layouts.length === 0)
            layouts.push(Settings.keyboardLayouts[0]);
        return {
            gaps_in: w.gapsIn,
            gaps_out: w.gapsOut,
            rounding: w.rounding,
            dim_inactive: w.dimInactive,
            dim_strength: w.dimStrength,
            shadow: w.shadow,
            animations: !Settings.reduceMotion,
            kb_layout: layouts.map(l => l.layout).join(","),
            kb_variant: layouts.map(l => l.variant).join(","),
            kb_options: layouts.length > 1 ? i.layoutSwitch : "",
            repeat_rate: i.repeatRate,
            repeat_delay: i.repeatDelay,
            follow_mouse: i.followMouse ? 1 : 0,
            sensitivity: i.pointerSpeed,
            natural_scroll: i.naturalScroll,
            tap_to_click: i.tapToClick,
            disable_while_typing: i.disableWhileTyping
        };
    }
    onHyprSettingsChanged: settingsTimer.restart()

    // Sürgü sürüklenirken her adımda değil, durunca
    Timer {
        id: settingsTimer
        interval: 150
        onTriggered: root.applySettings()
    }

    function applySettings() {
        hyprEval(`desk.apply_settings(${toLua(hyprSettings)})`);
    }

    // JavaScript değeri → Lua tablosu
    function toLua(value) {
        if (Array.isArray(value))
            return "{ " + value.map(toLua).join(", ") + " }";
        if (value !== null && typeof value === "object")
            return "{ " + Object.keys(value).map(key => `${key} = ${toLua(value[key])}`).join(", ") + " }";
        if (typeof value === "string")
            return JSON.stringify(value);
        if (typeof value === "boolean")
            return value ? "true" : "false";
        if (typeof value === "number")
            return isFinite(value) ? String(value) : "0";
        return "nil";
    }

    Connections {
        target: Hyprland

        function onRawEvent(event) {
            if (event.name !== "configreloaded")
                return;
            root.liteApplied = null;
            reapply.restart();
        }
    }
    Timer {
        id: reapply
        interval: 500
        onTriggered: {
            root.applySettings();
            root.applyPower();
        }
    }

    // ---------- Vurgu rengi → uygulamalar ----------
    // Ayarlar'da vurgu değişince kitty ve Dolphin de aynı renge geçsin (ilk açılışta değil:
    // colors.sh ve updatenix zaten çalıştırıyor)
    readonly property string accent: Settings.s.appearance.accent
    property bool accentSeen: false
    onAccentChanged: {
        if (accentSeen)
            appsTimer.restart();
    }
    Timer {
        id: appsTimer
        interval: 800
        onTriggered: Commands.run(["python3", Quickshell.shellPath("scripts/apps_theme.py")], (exit, out) => {
            if (exit !== 0)
                console.warn(`Theming: apps_theme.py → ${out.trim()}`);
        })
    }
    Connections {
        target: Settings
        function onReadyChanged() {
            root.accentSeen = Settings.ready;
        }
    }
    Component.onCompleted: accentSeen = Settings.ready
}
