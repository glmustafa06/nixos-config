import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Pam
import qs.theme
import qs.services

// Kilidin işleyişi: Wayland oturum kilidi, şifre doğrulama (PAM), açılınca programdan çıkış.
// Görünüm LockContent.qml'de; kilitte her ekrana bir LockSurface.qml içinde.
//
// Şifre bütün ekranlarda ortak (password); hangi ekranda yazılırsa yazılsın aynı.
// PAM ayarı: /etc/pam.d/desk-lock (configuration.nix → security.pam.services.desk-lock);
// o yoksa ya da hata verirse sistemin giriş ayarı (login).
//
// Deneme hâli: DESK_LOCK_TEST=1 qs -p ~/.config/quickshell/desk/lock.qml
// Ekran kilitlenmez; aynı görünüm sıradan bir pencerede açılır. Doğru şifre ya da boşken Esc kapatır.
// Kilit ekranını (ve şifre doğrulamasını) gerçekten kilitlemeden denemek için.
Scope {
    id: root

    readonly property bool testMode: Quickshell.env("DESK_LOCK_TEST") === "1"

    property string password: ""
    readonly property bool busy: pam.active
    // Son denemenin sonucu: "", "wrong", "error"
    property string failure: ""
    property string failureText: ""
    property int attempts: 0
    // Yanlış şifrede kutu sallanır; her denemede artar, yüzeyler bunu izler
    property int shake: 0

    property string pamConfig: "login"
    property string pendingPassword: ""

    function submit() {
        if (busy || password === "")
            return;
        failure = "";
        pendingPassword = password;
        pam.config = pamConfig;
        if (!pam.start()) {
            pendingPassword = "";
            if (pamConfig !== "login") {
                pamConfig = "login";
                fail("error", "Doğrulama hatası; bir daha dene");
            } else {
                fail("error", "Doğrulama başlatılamadı");
            }
        }
    }

    function fail(kind, text) {
        failure = kind;
        failureText = text;
        password = "";
        shake++;
        KeyboardLayout.refresh(); // Caps Lock açık mı
    }

    function unlock() {
        password = "";
        lock.locked = false;
        quitTimer.start();
    }

    // Deneme hâlinde boşken Esc çıkar
    function cancel() {
        if (testMode)
            Qt.quit();
    }

    WlSessionLock {
        id: lock

        locked: !root.testMode

        LockSurface {
            lock: root
        }
    }

    Variants {
        model: root.testMode ? Quickshell.screens : []

        PanelWindow {
            required property var modelData
            screen: modelData

            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }
            exclusionMode: ExclusionMode.Ignore
            color: Colors.lockFallback
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "desk-lock-test"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

            LockContent {
                anchors.fill: parent
                lock: root
            }
        }
    }

    // Kilit açılınca: Hyprland'in kilidi kaldırmasına kısa bir süre tanı, sonra çık
    Timer {
        id: quitTimer
        interval: 300
        onTriggered: Qt.quit()
    }

    PamContext {
        id: pam

        // PAM şifreyi sorunca ver; başka bir şey sorarsa (parmak izi gibi) yalnızca mesajı göster
        onPamMessage: {
            if (responseRequired) {
                respond(root.pendingPassword);
                root.pendingPassword = "";
            } else if (messageIsError) {
                root.failureText = message;
            }
        }
        onCompleted: result => {
            root.pendingPassword = "";
            root.attempts++;
            if (result === PamResult.Success)
                root.unlock();
            else if (result === PamResult.Failed)
                root.fail("wrong", "Şifre yanlış");
            else if (result === PamResult.MaxTries)
                root.fail("error", "Çok fazla deneme; biraz bekle");
            else if (root.pamConfig !== "login") {
                // Kendi ayarımız hata verdiyse sistemin giriş ayarına geç: kilitte mahsur kalınmasın
                console.warn("Lock: " + root.pamConfig + " hata verdi; login ayarına geçiliyor");
                root.pamConfig = "login";
                root.fail("error", "Doğrulama hatası; bir daha dene");
            } else
                root.fail("error", root.failureText !== "" ? root.failureText : "Doğrulama hatası");
        }
        onError: error => console.warn("Lock: PAM hatası (kod " + error + ")")
    }

    // Kendi PAM ayarımız kuruluysa onu kullan
    Process {
        command: ["test", "-f", "/etc/pam.d/desk-lock"]
        running: true
        onExited: code => {
            if (code === 0)
                root.pamConfig = "desk-lock";
            else
                console.warn("Lock: /etc/pam.d/desk-lock yok; sistemin giriş ayarı (login) kullanılıyor");
        }
    }
}
