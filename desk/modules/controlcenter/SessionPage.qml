import QtQuick
import QtQuick.Layouts
import Quickshell

// Güç düğmesinin sayfası: kilitle, uyku, yeniden başlat, kapat, oturumu kapat.
// Geri alınamayanlar ikinci tıklamayla onaylanır.
ColumnLayout {
    id: root

    required property var center

    // Onay bekleyen eylem (3 sn içinde tekrar tıklanmazsa vazgeçilir)
    property string confirming: ""

    spacing: 8

    readonly property var actions: [
        {
            id: "lock",
            icon: "lock",
            title: "Kilitle",
            command: ["loginctl", "lock-session"]
        },
        {
            id: "suspend",
            icon: "moon",
            title: "Uyku",
            // Önce kilitlenir, uyanınca kilit ekranı gelir
            command: ["sh", "-c", "loginctl lock-session && sleep 1 && systemctl suspend"]
        },
        {
            id: "reboot",
            icon: "rotate-ccw",
            title: "Yeniden başlat",
            confirm: true,
            command: ["systemctl", "reboot"]
        },
        {
            id: "poweroff",
            icon: "power",
            title: "Kapat",
            confirm: true,
            command: ["systemctl", "poweroff"]
        },
        {
            id: "logout",
            icon: "log-out",
            title: "Oturumu kapat",
            confirm: true,
            // Oturum UWSM ile açıldı; düzgün kapanması için onunla kapatılır
            command: ["uwsm", "stop"]
        }
    ]

    function run(action) {
        if (action.confirm && confirming !== action.id) {
            confirming = action.id;
            confirmTimer.restart();
            return;
        }
        confirming = "";
        center.close();
        Quickshell.execDetached(action.command);
    }

    Timer {
        id: confirmTimer
        interval: 3000
        onTriggered: root.confirming = ""
    }

    PageHeader {
        Layout.fillWidth: true
        title: "Güç"
        showBack: root.center.canGoBack
        onBack: root.center.back()
    }

    Repeater {
        model: root.actions

        delegate: ListRow {
            required property var modelData
            readonly property bool waiting: root.confirming === modelData.id

            Layout.fillWidth: true
            icon: modelData.icon
            title: modelData.title
            subtitle: waiting ? "Onaylamak için tekrar tıkla" : ""
            active: waiting
            onClicked: root.run(modelData)
        }
    }
}
