pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.settings

// Ayarlar → Pil ve güç'ün desk dışındaki karşılıkları:
//  - boşta kalınca karartma, kilit, uyku süreleri → ~/.local/state/desk/hypridle.conf
//    (hypridle servisi bu dosyayla başlar: nix/home.nix; değişince servis yeniden başlatılır)
//  - kapak kapanınca → ~/.local/state/desk/lid.env (hypr/scripts/lid.sh her seferinde okur)
//  - pil koruma → scripts/battery_care.sh (izin: nix/nixos.nix'teki udev kuralı)
// Dosyalar yalnızca içerik değişince yazılır; açılışta aynıysa hypridle'a dokunulmaz.
Singleton {
    id: root

    readonly property var power: Settings.s.power
    readonly property string stateDir: Quickshell.env("HOME") + "/.local/state/desk"

    function start() {
        // Settings'e ilk dokunuş bu tekili kurar; dosyalar ve pil koruma hemen denetlenir
        writeTimer.restart();
        careProbe.running = true;
    }

    // ---------- hypridle ----------
    readonly property string idleScript: "~/.config/hypr/scripts/idle.sh"

    function listener(minutes, action, source, resume) {
        return `
listener {
    timeout = ${minutes * 60}
    on-timeout = ${idleScript} ${action} ${source}
    on-resume = ${idleScript} ${resume}
}
`;
    }

    readonly property string idleText: {
        const p = power;
        let text = `# desk'in yazdığı dosya (Ayarlar → Pil ve güç; desk/services/PowerSettings.qml).
# Elle değiştirme: ayar değişince yeniden yazılır. Varsayılanlar: ~/.config/hypr/hypridle.conf
# Pilde: karart ${p.batteryDim}, kilitle ${p.batteryLock}, uyu ${p.batterySuspend} dk
# Prizde: karart ${p.acDim}, kilitle ${p.acLock}, uyu ${p.acSuspend} dk (0: hiçbir zaman)

general {
    lock_cmd = qs -n -p ~/.config/quickshell/desk/lock.qml
    before_sleep_cmd = loginctl lock-session
    after_sleep_cmd = hyprctl dispatch 'hl.dsp.dpms({ action = "on" })'
    inhibit_sleep = 3
}
`;
        for (const [source, prefix] of [["battery", "battery"], ["ac", "ac"]]) {
            const dim = p[prefix + "Dim"];
            const lock = p[prefix + "Lock"];
            const suspend = p[prefix + "Suspend"];
            if (dim > 0)
                text += listener(dim, "dim", source, "undim");
            if (lock > 0)
                text += listener(lock, "lock", source, "wake");
            if (suspend > 0)
                text += listener(suspend, "suspend", source, "wake");
        }
        return text;
    }

    readonly property string lidText: `LID_ACTION=${power.lidAction === "suspend" ? "suspend" : "lock"}\nLID_SUSPEND_MINUTES=${Math.max(0, Math.round(power.lidSuspend))}\n`

    onIdleTextChanged: writeTimer.restart()
    onLidTextChanged: writeTimer.restart()

    Timer {
        id: writeTimer
        interval: 600
        onTriggered: {
            root.writeIfChanged(idleFile, root.idleText, true);
            root.writeIfChanged(lidFile, root.lidText, false);
        }
    }

    // Yazılınca hypridle yeniden başlasın mı (dosya kaydedilince)
    property bool restartIdle: false

    function writeIfChanged(view, text, isIdle) {
        if (!Settings.ready)
            return;
        if (view.known && view.text() === text)
            return;
        Commands.run(["mkdir", "-p", stateDir], () => {
            if (isIdle)
                root.restartIdle = true;
            view.setText(text);
        });
    }

    FileView {
        id: idleFile
        // known: dosyaya bakıldı (yoksa da true: boş sayılır)
        property bool known: false
        path: root.stateDir + "/hypridle.conf"
        blockLoading: true
        printErrors: false
        onLoaded: known = true
        onLoadFailed: known = true
        onSaved: {
            if (!root.restartIdle)
                return;
            root.restartIdle = false;
            // Servis yoksa (desk elle açıldıysa) bir şey yapmaz
            Commands.run(["systemctl", "--user", "try-restart", "hypridle.service"], (exit, out) => {
                if (exit !== 0)
                    console.warn(`PowerSettings: hypridle yeniden başlatılamadı: ${out.trim()}`);
            });
        }
        onSaveFailed: error => console.warn(`PowerSettings: ${path} yazılamadı (${error})`)
    }

    FileView {
        id: lidFile
        property bool known: false
        path: root.stateDir + "/lid.env"
        blockLoading: true
        printErrors: false
        onLoaded: known = true
        onLoadFailed: known = true
        onSaveFailed: error => console.warn(`PowerSettings: ${path} yazılamadı (${error})`)
    }

    // ---------- Pil koruma ----------
    // kind: "ideapad" (Lenovo, ~%60), "threshold" (%80), "none" (yok), "" (henüz bakılmadı)
    property string careKind: ""
    property bool careOn: false
    property bool careWritable: false
    property string careError: ""
    readonly property bool careSupported: careKind === "ideapad" || careKind === "threshold"
    readonly property string careDetail: careKind === "ideapad" ? "Şarj %60 civarında durur (Lenovo koruma modu). Bilgisayar çoğunlukla prizdeyse pili uzun yaşatır." : careKind === "threshold" ? "Şarj %80'de durur. Bilgisayar çoğunlukla prizdeyse pili uzun yaşatır." : careKind === "" ? "Bakılıyor…" : "Bu bilgisayarda desteklenmiyor"
    readonly property string careScript: Quickshell.shellPath("scripts/battery_care.sh")

    Process {
        id: careProbe
        command: ["bash", root.careScript, "status"]
        stdout: StdioCollector {
            onStreamFinished: {
                const [kind, on, writable] = text.trim().split(/\s+/);
                root.careKind = kind || "none";
                root.careOn = on === "1";
                root.careWritable = writable === "1";
                root.syncCare();
            }
        }
    }

    // Ayar ile donanım farklıysa ayarı uygula (açılışta ve ayar değişince). Olmazsa aynı değer için
    // bir daha denenmez (ayar değişene kadar).
    readonly property bool careWanted: power.batteryCare
    property var careAttempt: null
    onCareWantedChanged: {
        careAttempt = null;
        careError = "";
        syncCare();
    }

    function syncCare() {
        if (!careSupported || careWanted === careOn || careSetter.running || careAttempt === careWanted)
            return;
        careAttempt = careWanted;
        if (!careWritable) {
            careError = "İzin yok: updatenix'ten sonra bilgisayarı yeniden başlat";
            return;
        }
        careError = "";
        careSetter.command = ["bash", careScript, "set", careWanted ? "on" : "off"];
        careSetter.running = true;
    }

    Process {
        id: careSetter
        stderr: StdioCollector {
            id: careStderr
        }
        onExited: code => {
            if (code !== 0)
                root.careError = careStderr.text.trim() || "Pil koruma değiştirilemedi";
            careProbe.running = true;
        }
    }
}
