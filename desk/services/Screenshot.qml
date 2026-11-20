pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import qs.theme
import qs.settings

// Ekran görüntüsü ve ekran kaydı.
//
//   Print       ekran donar, seçim ekranı açılır (modules/screenshot/ScreenshotOverlay.qml):
//               alan sürükle, pencereye tıkla ya da bütün ekran; altta araç çubuğu
//               (görüntü/kayıt, alan/pencere/ekran, bekleme süresi, kayıtta ses)
//   Shift+Print bütün ekran hemen
//   Print       kayıt sürerken: kaydı durdurur (adadaki kırmızı noktaya tıklamak da)
//
// Görüntü: Resimler/Ekran görüntüleri'ne kaydedilir ve panoya kopyalanır; sağ altta küçük önizleme
// çıkar (ShotPreview.qml). Önizlemeye tıklayınca Satty'de düzenlenir (ok, yazı, bulanıklaştırma).
// Pencere görüntüsünün köşeleri saydam yuvarlatılır (pencerenin kendi köşesi gibi).
// Kayıt: Videolar/Ekran kayıtları'na; gpu-screen-recorder (ekran kartında kodlar, pili az yorar),
// başlatamazsa wf-recorder. Kayıt sürerken adada kırmızı nokta ve süre.
//
// Kesip kaydetme scripts/capture.sh'te (grim, ImageMagick, wl-copy).
Singleton {
    id: root

    // ---------- Durum ----------
    // phase: idle · freezing (ekran yakalanıyor) · selecting (seçim ekranı açık) · countdown (bekleme)
    // · capturing · recording · stopping
    property string phase: "idle"
    readonly property bool busy: phase !== "idle"
    readonly property bool selecting: phase === "selecting"
    readonly property bool recording: phase === "recording" || phase === "stopping"

    // Araç çubuğundaki seçimler (bir sonraki açılışta da aynı kalır)
    property string kind: "shot"      // shot (görüntü) · record (kayıt)
    property string area: "region"    // region (alan) · window (pencere) · screen (ekran)
    property int delay: 0             // bekleme: 0, 3, 10 sn
    // Kayıtta bilgisayarın sesi: seçim ekranındaki düğme Ayarlar'a yazar (bir sonraki kayıtta da öyle)
    readonly property bool recordAudio: Settings.s.screenshot.audio
    function setRecordAudio(on) {
        Settings.set("screenshot.audio", on);
    }

    // Seçimin yapıldığı ekran
    property string screenName: ""
    property var monitor: null
    property string frozen: ""        // donmuş ekranın dosyası
    property int serial: 0

    property int countdown: 0         // bekleme sırasında kalan saniye (adada görünür)
    // Pencere görüntüsünün köşesi: Hyprland'deki pencere köşesiyle aynı (hypr/config/appearance.lua → rounding)
    // Pencere çekiminde köşeler Hyprland'deki gibi yuvarlak (Ayarlar → Pencereler → Köşeler)
    readonly property int windowRadius: Settings.s.windows.rounding

    // Son çekilen (köşedeki önizleme)
    property string lastFile: ""
    property string lastThumb: ""
    property bool lastIsVideo: false
    property int lastDuration: 0      // kayıtta saniye
    property int previewSerial: 0     // her yeni çekimde artar: önizleme yeniden belirir

    // Kayıt
    property real recordStart: 0
    property int elapsed: 0           // saniye (adada)
    property string recordFile: ""
    property string recorderName: ""  // gpu-screen-recorder ya da wf-recorder
    property var recordArgs: null     // yedeğe geçerken yeniden kullanılır

    // ---------- Yerler ----------
    readonly property string home: Quickshell.env("HOME")
    readonly property string runtimeDir: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/desk-shot"
    readonly property string script: Quickshell.shellPath("scripts/capture.sh")
    property string picturesDir: home + "/Pictures"
    property string videosDir: home + "/Videos"
    readonly property string shotsDir: picturesDir + "/Ekran görüntüleri"
    readonly property string recordingsDir: videosDir + "/Ekran kayıtları"

    // Türkçe kurulumda "Resimler", "Videolar" olabilir
    FileView {
        path: root.home + "/.config/user-dirs.dirs"
        printErrors: false
        onLoaded: {
            const dirs = text();
            const read = key => {
                const m = dirs.match(new RegExp("^" + key + '="(.*)"\\s*$', "m"));
                const dir = m ? m[1].replace("$HOME", root.home) : "";
                return dir !== "" && dir !== root.home ? dir : "";
            };
            root.picturesDir = read("XDG_PICTURES_DIR") || root.home + "/Pictures";
            root.videosDir = read("XDG_VIDEOS_DIR") || root.home + "/Videos";
        }
    }

    function stamp() {
        return new Date().toLocaleString(Qt.locale("C"), "yyyy-MM-dd HH.mm.ss");
    }

    // ---------- Başlatma ----------
    // Print: seçim ekranı. Kayıt sürüyorsa durdurur; seçim açıksa kapatır.
    // forceKind: "shot" ya da "record" (aramadan "Ekran kaydı")
    function start(forceKind) {
        if (recording) {
            stopRecording();
            return;
        }
        if (phase === "selecting" || phase === "countdown") {
            cancel();
            return;
        }
        if (phase !== "idle")
            return;
        if (forceKind)
            kind = forceKind;
        const mon = Hyprland.focusedMonitor;
        monitor = mon;
        screenName = mon?.name ?? "";
        // Pencere seçimi için yerleri tazelensin
        Hyprland.refreshToplevels();
        phase = "freezing";
        // Önceki çekimin önizlemesi yeni görüntüye girmesin: önce kalkar, sonra ekran donar
        previewHideRequested();
        freezeTimer.restart();
    }

    signal previewHideRequested

    Timer {
        id: freezeTimer
        interval: 120
        onTriggered: root.freeze()
    }

    function freeze() {
        const file = `${runtimeDir}/frozen-${++serial}.png`;
        Commands.run(["bash", script, "freeze", file, screenName], (code, out, err) => {
            if (root.phase !== "freezing")
                return;
            if (code !== 0) {
                root.phase = "idle";
                root.fail("Ekran yakalanamadı", err);
                return;
            }
            root.frozen = file;
            root.phase = "selecting";
        });
    }

    // Aramadan: arama kapanana kadar biraz beklenir (kapanırken görüntüye girmesin)
    function startLater(forceKind) {
        laterKind = forceKind ?? "";
        laterTimer.restart();
    }
    property string laterKind: ""
    Timer {
        id: laterTimer
        interval: 350
        onTriggered: root.start(root.laterKind)
    }

    // Shift+Print: bütün ekran hemen
    function captureScreen() {
        if (busy)
            return;
        const mon = Hyprland.focusedMonitor;
        screenName = mon?.name ?? "";
        phase = "capturing";
        previewHideRequested();
        screenTimer.restart();
    }
    Timer {
        id: screenTimer
        interval: 120
        onTriggered: {
            const file = `${root.shotsDir}/Ekran görüntüsü ${root.stamp()}.png`;
            Commands.run(["bash", root.script, "output", root.screenName, file, "copy"], (code, out, err) => root.captured(code, err, file));
        }
    }

    function cancel() {
        freezeTimer.stop();
        countdownTimer.stop();
        pending = null;
        phase = "idle";
    }

    // ---------- Seçim bitti ----------
    // rect: seçim ekranına göre (mantıksal piksel); isWindow: pencere seçildi (köşeler yuvarlatılır)
    function finish(rect, isWindow) {
        if (phase !== "selecting")
            return;
        const r = {
            x: Math.max(0, Math.round(rect.x)),
            y: Math.max(0, Math.round(rect.y)),
            width: Math.max(1, Math.round(rect.width)),
            height: Math.max(1, Math.round(rect.height)),
            window: isWindow === true,
            full: rect.full === true
        };
        pending = r;
        if (delay > 0) {
            countdown = delay;
            phase = "countdown";
            countdownTimer.restart();
        } else {
            go();
        }
    }

    property var pending: null

    Timer {
        id: countdownTimer
        interval: 1000
        repeat: true
        onTriggered: {
            root.countdown -= 1;
            if (root.countdown <= 0) {
                stop();
                // Ada bekleme göstergesini bıraksın, sonra çek
                root.phase = "capturing";
                goTimer.restart();
            }
        }
    }
    Timer {
        id: goTimer
        interval: 180
        onTriggered: root.go()
    }

    function monitorScale() {
        return monitor?.scale ?? monitor?.lastIpcObject?.scale ?? 1;
    }
    function monitorOrigin() {
        return Qt.point(monitor?.x ?? monitor?.lastIpcObject?.x ?? 0, monitor?.y ?? monitor?.lastIpcObject?.y ?? 0);
    }

    function go() {
        const r = pending;
        pending = null;
        if (!r) {
            phase = "idle";
            return;
        }
        if (kind === "record") {
            startRecording(r);
            return;
        }
        phase = "capturing";
        const file = `${shotsDir}/Ekran görüntüsü ${stamp()}.png`;
        const scale = monitorScale();
        const radius = r.window ? Math.round(windowRadius * scale) : 0;
        let command;
        if (delay === 0) {
            // Donmuş görüntüden kes (seçerken görülenin aynısı)
            const geometry = `${Math.round(r.width * scale)}x${Math.round(r.height * scale)}+${Math.round(r.x * scale)}+${Math.round(r.y * scale)}`;
            command = ["bash", script, "crop", frozen, geometry, String(radius), file, "copy"];
        } else if (r.full) {
            command = ["bash", script, "output", screenName, file, "copy"];
        } else {
            // Bekledikten sonra ekranın o anki hâli
            const o = monitorOrigin();
            command = ["bash", script, "grab", `${o.x + r.x},${o.y + r.y} ${r.width}x${r.height}`, String(radius), file, "copy"];
        }
        Commands.run(command, (code, out, err) => root.captured(code, err, file));
    }

    function captured(code, err, file) {
        phase = "idle";
        if (code !== 0) {
            fail("Ekran görüntüsü kaydedilemedi", err);
            return;
        }
        showPreview(file, file, false, 0);
    }

    function showPreview(file, thumb, isVideo, duration) {
        lastFile = file;
        lastThumb = thumb;
        lastIsVideo = isVideo;
        lastDuration = duration;
        previewSerial++;
    }

    function fail(title, err) {
        const detail = String(err ?? "").trim().split("\n").filter(l => l !== "").pop() ?? "";
        console.warn("desk/screenshot:", title, detail);
        Notifications.notify("Ekran görüntüsü", title, detail || "Ayrıntı: journalctl --user -u desk", "camera", 1, null, "screenshot");
    }

    // ---------- Kayıt ----------
    function startRecording(r) {
        const o = monitorOrigin();
        // Kodlayıcılar çift boyut ister
        const w = Math.max(2, r.width - r.width % 2);
        const h = Math.max(2, r.height - r.height % 2);
        recordFile = `${recordingsDir}/Ekran kaydı ${stamp()}.mp4`;
        recordArgs = {
            full: r.full,
            x: o.x + r.x,
            y: o.y + r.y,
            width: w,
            height: h
        };
        // Önizlemenin küçük resmi: donmuş görüntüden aynı yer
        const scale = monitorScale();
        const thumb = `${runtimeDir}/record-${serial}.png`;
        Commands.run(["bash", script, "crop", frozen, `${Math.round(w * scale)}x${Math.round(h * scale)}+${Math.round(r.x * scale)}+${Math.round(r.y * scale)}`, "0", thumb], () => {});
        recordThumb = thumb;
        Commands.run(["mkdir", "-p", recordingsDir], () => root.launchRecorder("gpu-screen-recorder"));
        phase = "recording";
    }
    property string recordThumb: ""

    function recorderCommand(name) {
        const a = recordArgs;
        if (name === "gpu-screen-recorder") {
            const command = ["gpu-screen-recorder"];
            if (a.full && screenName !== "")
                command.push("-w", screenName);
            else
                command.push("-w", "region", "-region", `${a.width}x${a.height}+${a.x}+${a.y}`);
            command.push("-f", String(Settings.s.screenshot.fps), "-cursor", Settings.s.screenshot.cursor ? "yes" : "no");
            if (recordAudio)
                command.push("-a", "default_output");
            command.push("-o", recordFile);
            return command;
        }
        // Yedek: wf-recorder (işlemcide kodlar; ses yok)
        return ["wf-recorder", "-y", "-g", `${a.x},${a.y} ${a.width}x${a.height}`, "-f", recordFile];
    }

    function launchRecorder(name) {
        if (phase !== "recording")
            return;
        recorderName = name;
        recorder.command = recorderCommand(name);
        recordStart = Date.now();
        elapsed = 0;
        recorder.running = true;
    }

    function stopRecording() {
        if (phase !== "recording")
            return;
        phase = "stopping";
        recorder.signal(2); // SIGINT: kaydı bitirip dosyayı yazar
        stopGuard.restart();
    }

    // Kayıt programı durmazsa 5 sn sonra zorla kapatılır
    Timer {
        id: stopGuard
        interval: 5000
        onTriggered: {
            if (recorder.running)
                recorder.signal(9);
        }
    }

    Timer {
        running: root.recording
        interval: 1000
        repeat: true
        onTriggered: root.elapsed = Math.floor((Date.now() - root.recordStart) / 1000)
    }

    Process {
        id: recorder

        stderr: StdioCollector {
            id: recorderErr
        }

        onExited: code => {
            stopGuard.stop();
            const quick = Date.now() - root.recordStart < 2500;
            // Hemen düştü: gpu-screen-recorder başlayamadı (izin, sürücü); yedeğe geç
            if (root.phase === "recording" && quick && root.recorderName === "gpu-screen-recorder") {
                console.warn("desk/screenshot: gpu-screen-recorder başlamadı, wf-recorder deneniyor:", recorderErr.text.trim().split("\n").pop());
                Qt.callLater(() => root.launchRecorder("wf-recorder"));
                return;
            }
            if (root.phase === "recording" && quick) {
                root.phase = "idle";
                root.fail("Ekran kaydı başlatılamadı", recorderErr.text);
                return;
            }
            const duration = Math.round((Date.now() - root.recordStart) / 1000);
            const file = root.recordFile;
            root.phase = "idle";
            Commands.run(["test", "-s", file], ok => {
                if (ok === 0)
                    root.showPreview(file, root.recordThumb, true, duration);
                else
                    root.fail("Ekran kaydı kaydedilemedi", recorderErr.text);
            });
        }
    }

    // ---------- Önizlemeden ----------
    // Düzenle: görüntü Satty'de (Enter kaydeder ve kopyalar, Esc vazgeçer); kayıt oynatıcıda
    function edit(file) {
        if (file.endsWith(".mp4")) {
            Commands.open(["xdg-open", file]);
            return;
        }
        const config = `${runtimeDir}/satty.toml`;
        Commands.run(["sh", "-c", 'mkdir -p "$(dirname "$2")" && printf "%s" "$1" > "$2"', "sh", sattyConfig(file), config], () => Commands.open(["satty", "--config", config, "--filename", file]));
    }

    function toml(text) {
        return '"' + String(text).replace(/\\/g, "\\\\").replace(/"/g, '\\"') + '"';
    }

    // Satty'nin ayarı: desk'in yazı tipi ve renkleri (ilk renk kırmızı, ikincisi vurgu rengi)
    function sattyConfig(file) {
        const accent = String(Colors.accent).replace("#", "").slice(-6);
        return ["[general]", 'resize = { mode = "smart" }', "floating-hack = true", "corner-roundness = 8", 'initial-tool = "arrow"', 'copy-command = "wl-copy"', "annotation-size-factor = 1.4", `output-filename = ${toml(file)}`, "disable-notifications = true", 'actions-on-enter = ["save-to-clipboard", "save-to-file", "exit"]', 'actions-on-escape = ["exit"]', "no-window-decoration = true", "", "[font]", 'family = "Inter"', 'style = "Regular"', "", "[color-palette]", `palette = ["#ff3b30ff", "#${accent}ff", "#ffcc00ff", "#34c759ff", "#0a84ffff", "#ffffffff", "#1c1c1eff"]`, ""].join("\n");
    }

    function showInFolder(file) {
        Commands.open(["dolphin", "--select", file]);
    }

    // Çöpe (Dolphin'in çöp kutusundan geri alınır)
    function remove(file) {
        Trash.trashFiles([file]);
    }
}
