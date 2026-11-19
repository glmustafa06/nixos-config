pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Ekran parlaklığı (dizüstünün kendi ekranı).
// Değer /sys'ten okunur, brightnessctl ile yazılır. Çekirdek parlaklık değişince
// haber vermediği için tuşlar değeri değiştirdikten sonra refresh() çağrılır
// (shell.qml'deki "osd" IPC'si, keybinds.lua).
Singleton {
    id: root

    // Hyprland kısayollarıyla aynı aygıt (keybinds.lua: brightnessctl -d amdgpu_bl1)
    readonly property string device: "amdgpu_bl1"

    property int raw: 0
    property int max: 0
    readonly property bool available: max > 0

    // 0..1, göze göre. Kısayollar brightnessctl -e4 kullanıyor (ham = en yüksek × yüzde⁴);
    // sürgü ve gösterge de aynı ölçeği kullanıyor ki tuşla ve sürgüyle aynı yere gelinsin.
    readonly property real level: available ? Math.pow(raw / max, 1 / 4) : 0

    function refresh() {
        brightnessFile.reload();
        maxFile.reload();
    }

    // value: 0..1 (göze göre). Sürgü sürüklenirken çok sık çağrılır;
    // ekrana hemen yansısın diye değer önce burada güncellenir, komut arada bir gönderilir.
    function set(value) {
        const v = Math.max(0.02, Math.min(1, value));
        if (available)
            raw = Math.round(Math.pow(v, 4) * max);
        pending = Math.round(v * 100);
        if (!throttle.running) {
            apply();
            throttle.start();
        }
    }

    property int pending: -1

    function apply() {
        if (pending < 0)
            return;
        Quickshell.execDetached(["brightnessctl", "-d", device, "-e4", "-n2", "set", pending + "%"]);
        pending = -1;
    }

    // Sürüklerken en fazla saniyede ~15 komut
    Timer {
        id: throttle
        interval: 66
        onTriggered: root.apply()
    }

    FileView {
        id: brightnessFile
        path: `/sys/class/backlight/${root.device}/brightness`
        onLoaded: root.raw = parseInt(text()) || 0
    }

    FileView {
        id: maxFile
        path: `/sys/class/backlight/${root.device}/max_brightness`
        onLoaded: root.max = parseInt(text()) || 0
    }
}
