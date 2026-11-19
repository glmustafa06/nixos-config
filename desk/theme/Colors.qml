pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Renkler: Grafit (koyu) tema.
// Yüzeyler sabit ve nötr; vurgu rengi ve barın görünümü duvar kâğıdından gelir.
//
// OKUNABİLİRLİK KURALI (18 Kasım): camın arkasında bembeyaz bir sayfa olsa bile
// yazılar okunmalı. Bu dosyada bir renk ya da saydamlık değiştirince:
//     python3 scripts/contrast.py
// Betik buradaki değerleri ve Hyprland'in blur ayarını okuyup en kötü durumu hesaplar;
// kural bozulursa söyler. Modüllerde elle renk yazma: hepsi buradan gelsin ki betik görsün.
Singleton {
    id: root

    // ===== Buzlu cam: menüler, kontrol merkezi, ses göstergesi, dock, arama =====
    // Hepsinin saydamlığı bu tek sayıdan gelir.
    // Bulanıklık ve arka planın karartılması Hyprland'de:
    //   nixos-config/hypr/config/appearance.lua → blur (size, brightness)
    readonly property real glassOpacity: 0.78
    // Taban: Hyprland'de blur brightness 0.8 iken bunun altında beyaz zeminde yazılar okunmuyor.
    // glassOpacity bundan düşük yazılırsa taban kullanılır (ve günlüğe uyarı düşer).
    // Daha saydam cam istersen: blur brightness'ı düşür, contrast.py yeni tabanı söyler, buraya yaz.
    readonly property real glassMinOpacity: 0.78
    readonly property color glass: Qt.rgba(30 / 255, 32 / 255, 36 / 255, Math.max(glassOpacity, glassMinOpacity))

    readonly property color panel: glass
    readonly property color panelBorder: Qt.rgba(1, 1, 1, 0.11)
    readonly property color glassEdge: Qt.rgba(1, 1, 1, 0.20)        // camın üst kenarındaki ince ışık (GlassEdge)
    readonly property color tile: Qt.rgba(1, 1, 1, 0.08)
    readonly property color tileBorder: Qt.rgba(1, 1, 1, 0.05)      // kutuların iç kenarı
    readonly property color tileHover: Qt.rgba(1, 1, 1, 0.12)       // tıklanabilir kutunun üstüne gelince
    readonly property color hover: Qt.rgba(1, 1, 1, 0.14)           // satırın üstüne gelince

    // --- Düğmeler ve alanlar
    readonly property color circleOff: Qt.rgba(1, 1, 1, 0.11)       // kapalı düğmenin zemini
    readonly property color circleOffIcon: "#e9e6e0"
    readonly property color circleHover: Qt.rgba(1, 1, 1, 0.18)
    readonly property color button: circleOff
    readonly property color buttonHover: Qt.rgba(1, 1, 1, 0.15)
    readonly property color field: Qt.rgba(0, 0, 0, 0.25)            // yazı kutusu
    readonly property color sliderTrack: Qt.rgba(1, 1, 1, 0.13)
    readonly property color sliderFill: "#efede8"
    readonly property color sliderIcon: "#55595e"
    readonly property color footerText: "#d2cfc9"
    // Tehlikeli eylemler (unut, sil)
    readonly property color danger: "#ffcdc7"
    readonly property color dangerFill: Qt.rgba(1, 0.4, 0.35, 0.10)
    readonly property color dangerFillHover: Qt.rgba(1, 0.4, 0.35, 0.16)

    // Uzun listede nerede olduğunu gösteren ince çizgi (arama, pano)
    readonly property color scrollIndicator: Qt.rgba(1, 1, 1, 0.28)
    // Klavyeyle seçilen ya da üstüne gelinen resmin çerçevesi (duvar kâğıdı seçici)
    readonly property color selectionRing: Qt.rgba(1, 1, 1, 0.55)

    // --- Menüler
    readonly property color menu: glass
    readonly property color menuSeparator: Qt.rgba(1, 1, 1, 0.09)

    // --- Dock (zemini de glass)
    readonly property color dockHover: Qt.rgba(1, 1, 1, 0.10)        // simgenin üstüne gelince arkası
    readonly property color dockIndicator: Qt.rgba(233 / 255, 230 / 255, 224 / 255, 0.62) // açık uygulamanın noktası
    readonly property color dockIndicatorFocused: accent                // odaktaki uygulamanınki
    readonly property color dockShadow: Qt.rgba(0, 0, 0, 0.32)         // dock'un altındaki yumuşak gölge
    readonly property color dockSeparator: Qt.rgba(1, 1, 1, 0.14)
    // Ad etiketi: küçük olduğu için bulanıklık yerine neredeyse örtücü
    readonly property color tooltip: Qt.rgba(30 / 255, 32 / 255, 36 / 255, 0.94)

    // --- Yazı
    readonly property color text: "#f3f1ed"
    readonly property color textMuted: "#c6cacf"   // ikincil bilgi (alt başlık, ağ adı)
    readonly property color textFaint: "#a9adb3"   // önemsiz bilgi (süre, ipucu, bölüm başlığı)

    // --- Durum renkleri
    readonly property color microphone: "#ff9a2a"
    readonly property color camera: "#4cd07d"
    readonly property color warning: "#ffb25e"     // camın üstündeki uyarı yazısı

    // ===== Ada (her zaman siyah; duvar kâğıdından etkilenmez) =====
    readonly property color island: "#000000"
    readonly property color islandText: "#cfcbc4"
    readonly property color islandMuted: "#a7a39c"   // sanatçı
    readonly property color islandFaint: "#8f8b85"   // süreler
    readonly property color islandTrack: Qt.rgba(1, 1, 1, 0.15)   // ilerleme çubuğunun boş kısmı
    readonly property color islandProgress: "#ebe8e2"
    readonly property color islandButton: Qt.rgba(1, 1, 1, 0.12)  // oynat/duraklat düğmesinin zemini
    readonly property color islandButtonHover: Qt.rgba(1, 1, 1, 0.08)
    readonly property color islandButtonActive: Qt.rgba(1, 1, 1, 0.18)  // dolu düğmenin üstüne gelince
    readonly property color islandDot: Qt.rgba(1, 1, 1, 0.62)     // penceresi olan çalışma alanı
    readonly property color islandDotEmpty: Qt.rgba(1, 1, 1, 0.22)
    readonly property color albumPlaceholder: "#1d2a2e"

    // ===== Kilit ekranı: duvar kâğıdının bulanık hâli üstünde beyaz yazı =====
    // Okunabilirlik scripts/contrast.py'de bembeyaz duvar kâğıdıyla denetlenir.
    // Karartma duvar kâğıdına göre: colors.sh (bar_tone.py) yazıların durduğu yerleri ölçüp
    // gereken en az karartmayı colors.json'a "lockDim" olarak yazar. Ölçülmemişse güvenli değer:
    // bembeyaz duvar kâğıdında bile okunur (contrast.py denetler).
    readonly property color lockFallback: "#14171b"                  // duvar kâğıdı yoksa
    readonly property real lockDimMin: 0.30
    readonly property real lockDimSafe: 0.45
    readonly property real lockDim: colorFile.lockDim > 0 ? Math.min(Math.max(colorFile.lockDim, lockDimMin), lockDimSafe) : lockDimSafe
    readonly property color lockShade: Qt.rgba(0, 0, 0, lockDim)
    readonly property color lockEdge: Qt.rgba(0, 0, 0, 0.40)         // üst ve alt kenarın ek karartması
    readonly property color lockText: "#ffffff"
    readonly property color lockMuted: Qt.rgba(1, 1, 1, 0.82)       // güç düğmelerinin adları
    readonly property color lockFaint: Qt.rgba(1, 1, 1, 0.62)       // şifre kutusundaki ipucu
    readonly property color lockShadow: Qt.rgba(0, 0, 0, 0.45)
    readonly property color lockField: Qt.rgba(1, 1, 1, 0.16)
    readonly property color lockFieldBorder: Qt.rgba(1, 1, 1, 0.22)
    readonly property color lockButton: Qt.rgba(1, 1, 1, 0.14)
    readonly property color lockButtonHover: Qt.rgba(1, 1, 1, 0.24)
    readonly property color lockError: "#e5484d"                      // yanlış şifrede kutunun kenarı

    // ===== Bar: duvar kâğıdına uyar (macOS gibi) =====
    // scripts/colors.sh duvar kâğıdının üst şeridini ölçer (scripts/bar_tone.py) ve
    // hangi görünümün daha okunur olduğunu colors.json'a "barTone" olarak yazar.
    // Yalnızca "Background" ve "Text" değerleri ölçümde kullanılır; değiştirirsen colors.sh'ı yeniden çalıştır.
    readonly property bool lightBar: colorFile.barTone === "light"
    // Renklerin üretildiği resim (colors.sh); duvar kâğıdı seçilmemişse başlangıç duvar kâğıdı bu olur
    readonly property string source: colorFile.source

    // Koyu duvar kâğıdı: açık yazı
    readonly property color barDarkBackground: Qt.rgba(16 / 255, 18 / 255, 22 / 255, 0.36)
    readonly property color barDarkBorder: Qt.rgba(1, 1, 1, 0.06)
    readonly property color barDarkText: "#f3f1ed"
    readonly property color barDarkTextMuted: "#c6cacf"
    readonly property color barDarkHover: Qt.rgba(1, 1, 1, 0.17)
    // Açık duvar kâğıdı: koyu yazı
    readonly property color barLightBackground: Qt.rgba(1, 1, 1, 0.30)
    readonly property color barLightBorder: Qt.rgba(0, 0, 0, 0.08)
    readonly property color barLightText: "#1b1d20"
    readonly property color barLightTextMuted: "#55585d"
    readonly property color barLightHover: Qt.rgba(0, 0, 0, 0.09)

    // Üst şerit karışıksa (yarısı beyaz, yarısı siyah) bar_tone.py zemini koyulaştırır
    readonly property color barBackground: {
        const base = lightBar ? barLightBackground : barDarkBackground;
        return Qt.rgba(base.r, base.g, base.b, Math.max(base.a, colorFile.barOpacity));
    }
    readonly property color barBorder: lightBar ? barLightBorder : barDarkBorder
    readonly property color barText: lightBar ? barLightText : barDarkText
    readonly property color barTextMuted: lightBar ? barLightTextMuted : barDarkTextMuted
    readonly property color barHover: lightBar ? barLightHover : barDarkHover
    // Açık barda vurgu ve uyarı renkleri koyulaşır (açık zeminde soluk kalmasınlar)
    readonly property color barAccent: lightBar ? Qt.hsla(accent.hslHue, accent.hslSaturation, 0.36, 1) : accent
    readonly property color barWarning: lightBar ? "#b85400" : microphone
    readonly property color trayHalo: Qt.rgba(0, 0, 0, 0.7)    // açık barda tepsi simgelerinin gölgesi

    // ===== Vurgu: matugen'in ürettiği renk =====
    // Çok soluk ya da çok parlak çıkarsa doygunluk ve açıklık sınırlanır
    // (karar: "vurgu duvar kâğıdından, uçlar dengelenir").
    // Mavi ve mor gibi koyu tonlar ayrıca açılır: camın üstünde simge olarak da okunmalı.
    readonly property real accentSaturationMin: 0.35
    readonly property real accentSaturationMax: 0.75
    readonly property real accentLightnessMin: 0.55
    readonly property real accentLightnessMax: 0.72
    readonly property real accentMinLuminance: 0.37
    readonly property color _raw: colorFile.accent
    readonly property color accent: readableAccent(_raw)
    readonly property color accentHover: Qt.lighter(accent, 1.08)
    // Vurgu renginin üstündeki yazı: aynı tonun çok koyusu
    readonly property color accentForeground: _raw.hslHue < 0 ? "#0b1714" : Qt.hsla(_raw.hslHue, 0.35, 0.08, 1)

    function clamp(value, low, high) {
        return Math.min(Math.max(value, low), high);
    }

    // WCAG göreli parlaklık (contrast.py'deki hesabın aynısı)
    function luminance(c) {
        const lin = v => v <= 0.04045 ? v / 12.92 : Math.pow((v + 0.055) / 1.055, 2.4);
        return 0.2126 * lin(c.r) + 0.7152 * lin(c.g) + 0.0722 * lin(c.b);
    }

    // scripts/themelib.py → accent_from ile aynı adımlar
    function readableAccent(raw) {
        if (raw.hslHue < 0)
            return raw; // gri: olduğu gibi
        const s = clamp(raw.hslSaturation, accentSaturationMin, accentSaturationMax);
        let l = clamp(raw.hslLightness, accentLightnessMin, accentLightnessMax);
        let c = Qt.hsla(raw.hslHue, s, l, 1);
        while (luminance(c) < accentMinLuminance && l < 0.9) {
            l += 0.01;
            c = Qt.hsla(raw.hslHue, s, l, 1);
        }
        return c;
    }

    Component.onCompleted: {
        if (glassOpacity < glassMinOpacity)
            console.warn(`Colors: glassOpacity ${glassOpacity} tabanın (${glassMinOpacity}) altında; taban kullanılıyor. Bkz. scripts/contrast.py`);
    }

    // scripts/colors.sh bu dosyayı yazar; değişince renk anında güncellenir
    FileView {
        path: Quickshell.env("HOME") + "/.local/state/desk/colors.json"
        watchChanges: true
        printErrors: false // dosya henüz yoksa sessizce varsayılanı kullan
        onFileChanged: reload()

        JsonAdapter {
            id: colorFile
            property string accent: "#5DBFAE" // dosya yoksa resimlerdeki yeşil
            property string accentForeground: "#0b1714"
            property string source: ""
            property string barTone: "dark" // "dark" ya da "light" (scripts/bar_tone.py)
            property real barOpacity: 0     // 0: yukarıdaki değer
            property real lockDim: 0        // 0: ölçülmedi (kilit ekranı lockDimSafe kullanır)
        }
    }
}
