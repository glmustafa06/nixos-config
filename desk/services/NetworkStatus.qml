pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Networking

// Ağ durumu ve Wi-Fi listesi (NetworkManager)
Singleton {
    id: root

    readonly property var wifiDevice: Networking.devices.values.find(d => d.type === DeviceType.Wifi) ?? null
    readonly property var wifiNetwork: wifiDevice?.networks.values.find(n => n.connected) ?? null
    readonly property bool wiredConnected: Networking.devices.values.some(d => d.type === DeviceType.Wired && d.connected)

    readonly property bool wifiEnabled: Networking.wifiEnabled
    readonly property bool wifiConnected: wifiNetwork !== null
    readonly property string ssid: wifiNetwork?.name ?? ""
    readonly property real strength: wifiNetwork?.signalStrength ?? 0 // 0..1

    // Barda hangi simge görünsün: "wifi", "ethernet" ya da "wifi-off"
    readonly property string kind: wifiConnected ? "wifi" : wiredConnected ? "ethernet" : "wifi-off"

    // Kontrol merkezinde Wi-Fi bloğunun alt yazısı
    readonly property string summary: {
        if (!wifiEnabled)
            return wiredConnected ? "Kapalı · kablo bağlı" : "Kapalı";
        if (wifiConnected)
            return ssid;
        return wiredConnected ? "Kablo bağlı" : "Bağlı değil";
    }

    function setWifiEnabled(on) {
        Networking.wifiEnabled = on;
    }

    // Wi-Fi sayfası açıkken çevredeki ağlar taranır (kapalıyken pil harcamasın)
    function setScanning(on) {
        if (wifiDevice)
            wifiDevice.scannerEnabled = on;
    }

    // Sinyal gücü → simgedeki yay sayısı (0–3). WifiIcon da bunu kullanır.
    function signalLevel(strength) {
        return strength >= 0.7 ? 3 : strength >= 0.45 ? 2 : strength >= 0.2 ? 1 : 0;
    }

    // Liste: bağlı olan, sonra kayıtlı olanlar, sonra sinyal düzeyine göre, aynı düzeydekiler ada göre.
    // Sinyal tam değeriyle değil düzeyiyle sıralanır: tarama sırasında güç biraz oynadı diye
    // satırlar yer değiştirmesin (tıklamak üzereyken satırın kayması can sıkar).
    // Sayfa bu diziyi ScriptModel'le kullanır; dizi değişince yalnızca değişen satırlar güncellenir.
    readonly property var networks: {
        if (!wifiDevice || !wifiEnabled)
            return [];
        return wifiDevice.networks.values.filter(n => n.name !== "").sort((a, b) => {
            if (a.connected !== b.connected)
                return a.connected ? -1 : 1;
            if (a.known !== b.known)
                return a.known ? -1 : 1;
            const level = signalLevel(b.signalStrength) - signalLevel(a.signalStrength);
            return level !== 0 ? level : a.name.localeCompare(b.name);
        });
    }

    function isSecured(network) {
        return network.security !== WifiSecurityType.Open && network.security !== WifiSecurityType.Owe;
    }

    // Şifreyle bağlanılabilen türler; kurumsal (EAP) ağlar burada desteklenmiyor
    function supportsPassword(network) {
        return [WifiSecurityType.WpaPsk, WifiSecurityType.Wpa2Psk, WifiSecurityType.Sae].includes(network.security);
    }

    // Kayıtlı ya da açık ağa doğrudan bağlanılır; yoksa şifre gerekir (false döner)
    function connect(network) {
        if (network.known || !isSecured(network)) {
            network.connect();
            return true;
        }
        return false;
    }

    // --- Ayrıntılar (ağ ayrıntıları sayfası)
    readonly property string interfaceName: wifiDevice?.name ?? ""
    readonly property string macAddress: wifiDevice?.address ?? ""

    function securityName(network) {
        switch (network?.security) {
        case WifiSecurityType.Open:
            return "Açık (şifresiz)";
        case WifiSecurityType.Owe:
            return "Açık (şifreli bağlantı)";
        case WifiSecurityType.Sae:
            return "WPA3";
        case WifiSecurityType.Wpa2Psk:
            return "WPA2";
        case WifiSecurityType.WpaPsk:
            return "WPA";
        case WifiSecurityType.Wpa2Eap:
        case WifiSecurityType.WpaEap:
        case WifiSecurityType.Wpa3SuiteB192:
            return "Kurumsal (802.1X)";
        case WifiSecurityType.StaticWep:
        case WifiSecurityType.DynamicWep:
            return "WEP (eski, güvensiz)";
        default:
            return "Bilinmiyor";
        }
    }

    // Kayıtlı ağın NetworkManager ayarı (otomatik bağlanma gibi)
    function settingsOf(network) {
        const list = network?.nmSettings ?? [];
        return list.length > 0 ? list[0] : null;
    }

    function autoconnect(network) {
        const settings = settingsOf(network);
        if (!settings)
            return false;
        return settings.read()?.connection?.autoconnect ?? true; // yazılmamışsa açık sayılır
    }

    function setAutoconnect(network, on) {
        settingsOf(network)?.write({
            connection: {
                autoconnect: on
            }
        });
    }
}
