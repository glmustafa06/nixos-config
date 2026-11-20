import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.theme
import qs.components
import qs.services
import qs.settings

// Hakkında: bilgisayar, sistem ve sürümler (scripts/sysinfo.sh); ayarlar dosyası ve sıfırlama
SettingsPage {
    id: page

    title: "Hakkında"

    property var info: ({})
    property bool confirmReset: false

    Process {
        running: true
        command: ["bash", Quickshell.shellPath("scripts/sysinfo.sh")]
        stdout: StdioCollector {
            onStreamFinished: {
                const result = {};
                for (const line of text.split("\n")) {
                    const at = line.indexOf("=");
                    if (at > 0)
                        result[line.slice(0, at)] = line.slice(at + 1).trim();
                }
                page.info = result;
            }
        }
    }

    function bytes(value) {
        const n = Number(value);
        if (!n)
            return "";
        const gb = n / 1024 / 1024 / 1024;
        return gb >= 100 ? Math.round(gb) + " GB" : gb.toLocaleString(Qt.locale("tr_TR"), "f", 1) + " GB";
    }

    function uptime(seconds) {
        const s = Number(seconds);
        if (!s)
            return "";
        const days = Math.floor(s / 86400), hours = Math.floor(s % 86400 / 3600), minutes = Math.floor(s % 3600 / 60);
        if (days > 0)
            return `${days} gün ${hours} sa`;
        if (hours > 0)
            return `${hours} sa ${minutes} dk`;
        return `${minutes} dk`;
    }

    readonly property var gpuNames: ({
            amdgpu: "AMD (tümleşik)",
            nvidia: "NVIDIA",
            i915: "Intel",
            xe: "Intel"
        })

    // Üstte: bilgisayarın adı ve modeli
    Item {
        Layout.fillWidth: true
        implicitHeight: 96

        Rectangle {
            id: hero
            width: 64
            height: 64
            anchors.verticalCenter: parent.verticalCenter
            radius: 16
            color: Colors.settingsCard
            border.width: 1
            border.color: Colors.settingsCardBorder

            Icon {
                anchors.centerIn: parent
                name: "laptop"
                size: 34
                strokeWidth: 1.8
                color: Colors.accent
            }
        }
        Column {
            anchors {
                left: hero.right
                leftMargin: 16
                right: parent.right
                verticalCenter: parent.verticalCenter
            }
            spacing: 3

            Text {
                width: parent.width
                text: page.info.model || page.info.host || "Bilgisayar"
                elide: Text.ElideRight
                color: Colors.text
                font.family: Typography.family
                font.pixelSize: 18
                font.weight: Font.DemiBold
            }
            Text {
                width: parent.width
                text: [page.info.vendor ? page.info.vendor.charAt(0) + page.info.vendor.slice(1).toLowerCase() : "", page.info.host].filter(s => s).join("  ·  ")
                elide: Text.ElideRight
                color: Colors.textMuted
                font.family: Typography.family
                font.pixelSize: Typography.body - 1
            }
            Text {
                text: "desk · Hyprland ve Quickshell üstünde"
                color: Colors.textFaint
                font.family: Typography.family
                font.pixelSize: Typography.small
            }
        }
    }

    SettingsSection {
        title: "Donanım"

        ValueRow {
            title: "İşlemci"
            value: {
                const parts = [];
                if (page.info.cores)
                    parts.push(`${page.info.cores} çekirdek`);
                if (page.info.threads && page.info.threads !== page.info.cores)
                    parts.push(`${page.info.threads} iş parçacığı`);
                return (page.info.cpu ?? "") + (parts.length > 0 ? `  (${parts.join(", ")})` : "");
            }
        }
        ValueRow {
            visible: (page.info.gpus ?? "") !== ""
            title: "Ekran kartı"
            value: (page.info.gpus ?? "").split(" ").filter(s => s).map(s => page.gpuNames[s] ?? s).join(", ")
        }
        ValueRow {
            title: "Bellek"
            value: page.bytes(page.info.memory)
        }
        ValueRow {
            title: "Disk"
            value: page.info.disk ? `${page.bytes(page.info.diskUsed)} dolu, ${page.bytes(page.info.disk)}` : ""
        }
    }

    SettingsSection {
        title: "Yazılım"

        ValueRow {
            title: "Sistem"
            value: page.info.os ?? ""
        }
        ValueRow {
            title: "Çekirdek"
            value: page.info.kernel ?? ""
        }
        ValueRow {
            title: "Hyprland"
            value: page.info.hyprland ?? ""
        }
        ValueRow {
            title: "Quickshell"
            value: page.info.quickshell ?? ""
        }
        ValueRow {
            title: "Açık kalma süresi"
            value: page.uptime(page.info.uptime)
        }
    }

    SettingsSection {
        title: "Ayarlar"
        footer: "Burada değiştirdiğin her şey bu dosyada; git'le saklanır, başka bilgisayara taşınır. Yalnızca varsayılandan farklı olanlar yazılır."

        ButtonRow {
            title: "Ayarlar dosyası"
            subtitle: Settings.path.replace(Quickshell.env("HOME"), "~")
            buttonText: "Aç"
            buttonIcon: "file-text"
            // Hiçbir şey değiştirilmediyse dosya henüz yok
            enabled: Object.keys(Settings.data).length > 0
            onClicked: Commands.open(["xdg-open", Settings.path])
        }
        ButtonRow {
            title: "Bütün ayarları sıfırla"
            subtitle: page.confirmReset ? "Emin misin? Bir kez daha bas." : "Her şey ilk hâline döner (dock'taki sabitlenenler de)"
            buttonText: page.confirmReset ? "Sıfırla" : "Sıfırla…"
            buttonIcon: "rotate-ccw"
            danger: true
            onClicked: {
                if (!page.confirmReset) {
                    page.confirmReset = true;
                    confirmTimer.restart();
                    return;
                }
                page.confirmReset = false;
                Settings.reset("");
            }
        }
    }

    Timer {
        id: confirmTimer
        interval: 4000
        onTriggered: page.confirmReset = false
    }
}
