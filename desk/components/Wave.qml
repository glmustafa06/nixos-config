import QtQuick
import qs.theme

// Müzik çalarken oynayan çubuklar. Duraklatınca alçalıp durur.
//
// Pil için saniyede 15 kare: sürekli çalışan bir QML animasyonu barı saniyede 60 kez
// yeniden çizdirir (Hyprland da her karede arkasını yeniden bulanıklaştırır).
// 13 piksellik çubuklarda 15 kare göze akıcı görünüyor; görünmezken hiç çalışmaz.
Row {
    id: root

    property int bars: 4
    property real maxHeight: 13
    property bool playing: false
    property color color: Colors.accent

    // Zaman (saniye); çubuklar bunun sinüsüyle inip çıkar
    property real phase: 0

    spacing: 2.5
    height: maxHeight

    Timer {
        running: root.playing && root.visible
        interval: 66
        repeat: true
        onTriggered: root.phase += interval / 1000
    }

    Repeater {
        model: root.bars

        delegate: Rectangle {
            id: bar

            required property int index
            // Her çubuğun kendi dinlenme yüksekliği ve hızı var, hep birlikte inip çıkmasınlar
            readonly property real base: [0.45, 0.9, 0.6, 1, 0.55][index % 5]
            readonly property real speed: [7.1, 5.3, 8.4, 6.2, 4.7][index % 5]
            readonly property real level: Math.max(0.2, Math.min(1, base + 0.35 * Math.sin(root.phase * speed + index * 1.7)))

            anchors.verticalCenter: parent.verticalCenter
            width: 3
            radius: 1.5
            height: root.maxHeight * (root.playing ? level : base * 0.45)
            color: root.color

            // Yalnızca duraklatınca/başlatınca yumuşak geçiş (çalarken her adım doğrudan)
            Behavior on height {
                enabled: !root.playing
                NumberAnimation { duration: Metrics.durationNormal }
            }
        }
    }
}
