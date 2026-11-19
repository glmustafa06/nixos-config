import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.theme
import qs.services

// Duvar kâğıdı: her ekranın en altında, pencerelerin arkasında.
// Resim değişince yenisi yüklenir, hazır olunca eskisinin üstünde belirir (yumuşak geçiş).
// Resim ekran boyutunda çözülür: 6K bir fotoğraf belleğe 6K olarak girmez.
PanelWindow {
    id: root

    required property var modelData
    screen: modelData

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Background
    WlrLayershell.namespace: "desk-wallpaper"
    color: "black"

    readonly property string source: Wallpaper.fileUrl(Wallpaper.current)
    readonly property size pixelSize: Qt.size(Math.round(width * (screen?.devicePixelRatio ?? 1)), Math.round(height * (screen?.devicePixelRatio ?? 1)))

    // Önde görünen resim ve yenisinin yüklendiği resim yer değiştirir
    property WallpaperImage front: first
    property WallpaperImage back: second

    // İlk açılışta da yeni resim siyahın üstünde belirir
    onSourceChanged: load()
    Component.onCompleted: load()

    function load() {
        if (source === "" || front.requested === source)
            return;
        back.requested = source;
    }

    function swap() {
        const old = front;
        front = back;
        back = old;
        fade.restart();
    }

    WallpaperImage {
        id: first
        opacity: 0
        z: root.front === first ? 1 : 0
        onStatusChanged: root.loaded(first)
    }
    WallpaperImage {
        id: second
        opacity: 0
        z: root.front === second ? 1 : 0
        onStatusChanged: root.loaded(second)
    }

    function loaded(image) {
        if (image !== back || image.requested === "")
            return;
        if (image.status === Image.Ready)
            swap();
        else if (image.status === Image.Error)
            console.warn("Wallpaper: resim açılamadı:", image.source);
    }

    // Yeni resim belirir; bitince arkada kalanı boşaltılır (bellek)
    SequentialAnimation {
        id: fade

        PropertyAction {
            target: root.front
            property: "opacity"
            value: 0
        }
        NumberAnimation {
            target: root.front
            property: "opacity"
            to: 1
            duration: 700
            easing.type: Easing.InOutQuad
        }
        ScriptAction {
            script: {
                root.back.opacity = 0;
                root.back.requested = "";
            }
        }
    }

    component WallpaperImage: Image {
        // İstenen adres (Qt'nin source'u adresi yeniden yazabilir; karşılaştırma bununla)
        property string requested: ""

        source: requested
        anchors.fill: parent
        fillMode: Image.PreserveAspectCrop
        sourceSize: root.pixelSize
        asynchronous: true
        cache: false
        smooth: true
    }
}
