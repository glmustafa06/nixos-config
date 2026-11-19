import QtQuick
import QtQuick.Layouts
import qs.theme
import qs.components
import qs.services

// Bir Wi-Fi ağının ayrıntıları: bağlan/kes, unut, otomatik bağlan, IP ve MAC adresleri, şifre.
// NetworkManager'ın Quickshell'de olmayan bilgileri (IP, kanal, şifre) nmcli ile okunur.
ColumnLayout {
    id: root

    required property var center
    required property var network

    readonly property bool connected: network?.connected ?? false
    readonly property bool known: network?.known ?? false

    // nmcli'den gelenler
    property string ipAddress: ""
    property string gateway: ""
    property string dns: ""
    property string band: ""
    property string rate: ""
    property string password: ""
    property string passwordError: ""
    property bool confirmForget: false
    property bool autoconnect: NetworkStatus.autoconnect(network)

    spacing: 8

    Component.onCompleted: loadDetails()
    onConnectedChanged: loadDetails()

    function loadDetails() {
        const iface = NetworkStatus.interfaceName;
        if (!connected || iface === "") {
            root.ipAddress = "";
            root.gateway = "";
            root.dns = "";
            root.band = "";
            root.rate = "";
            return;
        }
        Commands.run(["nmcli", "-t", "-f", "IP4.ADDRESS,IP4.GATEWAY,IP4.DNS", "device", "show", iface], (code, out) => {
            const dnsList = [];
            for (const line of out.split("\n")) {
                const [field, value] = Commands.splitTerse(line);
                if (!value)
                    continue;
                if (field.startsWith("IP4.ADDRESS") && root.ipAddress === "")
                    root.ipAddress = value.split("/")[0];
                else if (field === "IP4.GATEWAY")
                    root.gateway = value;
                else if (field.startsWith("IP4.DNS"))
                    dnsList.push(value);
            }
            root.dns = dnsList.join(", ");
        });
        Commands.run(["nmcli", "-t", "-f", "IN-USE,CHAN,FREQ,RATE", "device", "wifi", "list", "ifname", iface, "--rescan", "no"], (code, out) => {
            for (const line of out.split("\n")) {
                const [inUse, channel, freq, speed] = Commands.splitTerse(line);
                if (inUse !== "*")
                    continue;
                const mhz = parseInt(freq) || 0;
                const name = mhz >= 5925 ? "6 GHz" : mhz >= 4900 ? "5 GHz" : "2,4 GHz";
                root.band = `${name} · kanal ${channel}`;
                root.rate = (speed ?? "").replace("Mbit/s", "Mb/sn");
            }
        });
    }

    // Kayıtlı şifre NetworkManager'dan okunur; sistem bir kez parola isteyebilir
    function revealPassword() {
        const uuid = NetworkStatus.settingsOf(network)?.uuid ?? "";
        if (uuid === "")
            return;
        Commands.run(["nmcli", "-s", "-g", "802-11-wireless-security.psk", "connection", "show", "uuid", uuid], (code, out) => {
            const value = out.trim().replace(/\\(.)/g, "$1");
            if (code === 0 && value !== "") {
                root.password = value;
                root.passwordError = "";
            } else {
                root.passwordError = "Şifre okunamadı (yetki verilmedi ya da şifre kayıtlı değil).";
            }
        });
    }

    Timer {
        id: forgetTimer
        interval: 3000
        onTriggered: root.confirmForget = false
    }

    PageHeader {
        Layout.fillWidth: true
        title: root.network?.name ?? "Wi-Fi"
        showBack: root.center.canGoBack
        onBack: root.center.back()
    }

    // Ağ kapsama dışına çıktıysa
    Text {
        Layout.fillWidth: true
        Layout.margins: 8
        visible: root.network === null
        text: "Bu ağ artık listede değil."
        color: Colors.textMuted
        font.family: Typography.family
        font.pixelSize: Typography.small
    }

    ColumnLayout {
        Layout.fillWidth: true
        visible: root.network !== null
        spacing: 10

        // Durum
        Tile {
            Layout.fillWidth: true

            RowLayout {
                width: parent.width
                spacing: 12

                Rectangle {
                    implicitWidth: 40
                    implicitHeight: 40
                    radius: 20
                    color: root.connected ? Colors.accent : Colors.circleOff

                    WifiIcon {
                        anchors.centerIn: parent
                        size: 20
                        strength: root.network?.signalStrength ?? 0
                        color: root.connected ? Colors.accentForeground : Colors.circleOffIcon
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 1

                    Text {
                        Layout.fillWidth: true
                        text: root.connected ? "Bağlı" : root.network?.stateChanging ? "Bağlanıyor…" : root.known ? "Kayıtlı, bağlı değil" : "Bağlı değil"
                        color: Colors.text
                        font.family: Typography.family
                        font.pixelSize: Typography.body
                        font.weight: Font.DemiBold
                    }
                    Text {
                        Layout.fillWidth: true
                        text: `Sinyal %${Math.round((root.network?.signalStrength ?? 0) * 100)} · ${NetworkStatus.securityName(root.network)}`
                        color: Colors.textMuted
                        font.family: Typography.family
                        font.pixelSize: Typography.small
                    }
                }
            }
        }

        // Eylemler
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            TextButton {
                Layout.fillWidth: true
                text: root.connected ? "Bağlantıyı kes" : "Bağlan"
                accent: !root.connected
                onClicked: root.connected ? root.network.disconnect() : root.network.connect()
            }
            TextButton {
                Layout.fillWidth: true
                visible: root.known
                text: root.confirmForget ? "Emin misin? Tekrar bas" : "Bu ağı unut"
                danger: true
                onClicked: {
                    if (!root.confirmForget) {
                        root.confirmForget = true;
                        forgetTimer.restart();
                        return;
                    }
                    root.network.forget();
                    root.center.back();
                }
            }
        }

        SettingRow {
            Layout.fillWidth: true
            Layout.leftMargin: 4
            Layout.rightMargin: 4
            visible: root.known
            title: "Otomatik bağlan"
            subtitle: "Menzile girince bu ağa kendiliğinden bağlanır"
            checked: root.autoconnect
            onToggled: {
                root.autoconnect = !root.autoconnect;
                NetworkStatus.setAutoconnect(root.network, root.autoconnect);
            }
        }

        // Ayrıntılar
        SectionTitle {
            text: "Ayrıntılar"
        }

        Tile {
            Layout.fillWidth: true

            ColumnLayout {
                width: parent.width
                spacing: 8

                InfoRow {
                    Layout.fillWidth: true
                    visible: root.connected
                    label: "IP adresi"
                    value: root.ipAddress
                    copyable: true
                }
                InfoRow {
                    Layout.fillWidth: true
                    visible: root.connected
                    label: "Yönlendirici"
                    value: root.gateway
                    copyable: true
                }
                InfoRow {
                    Layout.fillWidth: true
                    visible: root.connected
                    label: "DNS"
                    value: root.dns
                }
                InfoRow {
                    Layout.fillWidth: true
                    visible: root.connected
                    label: "Bant"
                    value: root.band
                }
                InfoRow {
                    Layout.fillWidth: true
                    visible: root.connected
                    label: "Hız"
                    value: root.rate
                }
                InfoRow {
                    Layout.fillWidth: true
                    label: "Güvenlik"
                    value: NetworkStatus.securityName(root.network)
                }
                InfoRow {
                    Layout.fillWidth: true
                    label: "MAC adresi (bu bilgisayar)"
                    value: NetworkStatus.macAddress
                    copyable: true
                }
            }
        }

        // Kayıtlı şifre
        SectionTitle {
            visible: root.known && NetworkStatus.supportsPassword(root.network)
            text: "Şifre"
        }

        Tile {
            Layout.fillWidth: true
            visible: root.known && NetworkStatus.supportsPassword(root.network)

            ColumnLayout {
                width: parent.width
                spacing: 6

                InfoRow {
                    Layout.fillWidth: true
                    visible: root.password !== ""
                    label: "Şifre"
                    value: root.password
                    copyable: true
                }
                TextButton {
                    visible: root.password === ""
                    text: "Şifreyi göster"
                    onClicked: root.revealPassword()
                }
                Text {
                    Layout.fillWidth: true
                    visible: root.passwordError !== ""
                    text: root.passwordError
                    color: Colors.warning
                    font.family: Typography.family
                    font.pixelSize: Typography.small
                    wrapMode: Text.WordWrap
                }
            }
        }
    }
}
