pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.UPower

// Pil durumu (UPower)
Singleton {
    id: root

    readonly property var device: UPower.displayDevice

    readonly property bool present: device.ready && device.isLaptopBattery
    readonly property real level: device.percentage // 0..1
    readonly property bool onBattery: UPower.onBattery
    readonly property bool charging: device.state === UPowerDeviceState.Charging
        || device.state === UPowerDeviceState.PendingCharge
        || device.state === UPowerDeviceState.FullyCharged
    readonly property bool full: device.state === UPowerDeviceState.FullyCharged

    // Asıl pil (ayrıntılar için; displayDevice bunların özeti)
    readonly property var battery: UPower.devices.values.find(d => d.isLaptopBattery) ?? device

    // Pilden çekilen ya da pile giden güç (W), dolu kapasite (Wh), sağlık (%)
    readonly property real powerDraw: Math.abs(battery.changeRate)
    readonly property real capacity: battery.energyCapacity
    readonly property real health: battery.healthPercentage // 0..100, bilinmiyorsa 0

    // Kalan süre, saniye (UPower hesaplayamıyorsa 0)
    readonly property real timeToEmpty: device.timeToEmpty
    readonly property real timeToFull: device.timeToFull

    // Pil sayfasındaki durum satırı
    readonly property string stateText: {
        if (full)
            return "Dolu · prizde";
        if (device.state === UPowerDeviceState.PendingCharge)
            return "Prizde · şarj bekliyor";
        if (charging)
            return timeToFull > 0 ? `Şarj oluyor · dolmasına ${formatDuration(timeToFull)}` : "Şarj oluyor";
        return timeToEmpty > 0 ? `Pilde · ${formatDuration(timeToEmpty)} kaldı` : "Pilde";
    }

    // 13200 → "3 sa 40 dk"
    function formatDuration(seconds) {
        const minutes = Math.round(seconds / 60);
        const h = Math.floor(minutes / 60);
        const m = minutes % 60;
        if (h > 0 && m > 0)
            return `${h} sa ${m} dk`;
        if (h > 0)
            return `${h} sa`;
        return `${m} dk`;
    }

    // Kontrol merkezinin altındaki satır: "Pil %87 · 3 sa 40 dk"
    readonly property string summary: {
        const percent = "%" + Math.round(level * 100);
        if (!present)
            return "Prize takılı";
        if (full)
            return `Pil ${percent} · dolu`;
        if (charging)
            return timeToFull > 0 ? `Pil ${percent} · dolmasına ${formatDuration(timeToFull)}` : `Pil ${percent} · şarj oluyor`;
        return timeToEmpty > 0 ? `Pil ${percent} · ${formatDuration(timeToEmpty)}` : `Pil ${percent}`;
    }
}
