pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.UPower

// Güç modu (power-profiles-daemon): Tasarruf / Dengeli / Performans
Singleton {
    id: root

    readonly property int profile: PowerProfiles.profile
    readonly property bool hasPerformance: PowerProfiles.hasPerformanceProfile

    readonly property var modes: [
        {
            profile: PowerProfile.PowerSaver,
            name: "Tasarruf",
            icon: "leaf",
            detail: "Pil daha uzun gider, işlemci yavaşlar"
        },
        {
            profile: PowerProfile.Balanced,
            name: "Dengeli",
            icon: "zap",
            detail: "Günlük kullanım"
        },
        {
            profile: PowerProfile.Performance,
            name: "Performans",
            icon: "gauge",
            detail: "En hızlı, pil çabuk biter"
        }
    ]

    readonly property string name: modes.find(m => m.profile === profile)?.name ?? "Dengeli"

    function set(value) {
        if (value === PowerProfile.Performance && !hasPerformance)
            return;
        PowerProfiles.profile = value;
    }
}
