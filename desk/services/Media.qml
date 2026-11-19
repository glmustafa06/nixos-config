pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Mpris

// Çalan müzik (MPRIS): Spotify, tarayıcıdaki video ve benzerleri.
// Ada bilgiyi buradan okur.
Singleton {
    id: root

    // playerctld varsa diğer oynatıcıları kopyalıyor; iki kez görünmesin
    readonly property var players: Mpris.players.values.filter(p => !p.dbusName.includes("playerctld"))

    // Önce çalan, yoksa duraklatılmış oynatıcı. Durdurulmuş olanlar gösterilmez.
    readonly property var player: players.find(p => p.isPlaying) ?? players.find(p => p.playbackState === MprisPlaybackState.Paused) ?? null

    readonly property bool active: player !== null && player.trackTitle !== ""
    readonly property bool playing: player?.isPlaying ?? false

    readonly property string title: player?.trackTitle ?? ""
    readonly property string artist: player?.trackArtist ?? ""
    readonly property string artUrl: player?.trackArtUrl ?? ""
    readonly property string source: player?.identity ?? ""   // "Spotify", "Zen" …

    // Saniye cinsinden. Konum yalnızca okununca güncelleniyor (aşağıdaki sayaç)
    readonly property bool hasPosition: (player?.positionSupported ?? false) && length > 0
    readonly property real position: player?.position ?? 0
    readonly property real length: player?.length ?? 0
    readonly property bool canSeek: hasPosition && (player?.canSeek ?? false)

    // fraction: 0 = baş, 1 = son
    function seek(fraction) {
        if (canSeek)
            player.position = Math.max(0, Math.min(1, fraction)) * length;
    }

    // Oynatıcının penceresini öne getirir (Spotify gibi)
    function raise() {
        if (player?.canRaise)
            player.raise();
    }

    function togglePlaying() {
        if (player?.canTogglePlaying)
            player.togglePlaying();
    }
    function next() {
        if (player?.canGoNext)
            player.next();
    }
    function previous() {
        if (player?.canGoPrevious)
            player.previous();
    }

    // 83 → "1:23"
    function formatTime(seconds) {
        const total = Math.max(0, Math.floor(seconds));
        const s = total % 60;
        return Math.floor(total / 60) + ":" + (s < 10 ? "0" : "") + s;
    }

    // Quickshell konumu sürekli yaymıyor (işlemci harcamasın diye).
    // Ada açıkken saniyede bir "değişti" denir; yalnızca çalarken.
    property bool trackPosition: false
    Timer {
        running: root.trackPosition && root.playing
        interval: 1000
        repeat: true
        triggeredOnStart: true
        onTriggered: root.player?.positionChanged()
    }
}
