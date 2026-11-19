pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Io

// Bluetooth durumu ve cihaz listesi (BlueZ)
Singleton {
    id: root

    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property bool available: adapter !== null
    readonly property bool enabled: adapter?.enabled ?? false
    readonly property var connectedDevices: Bluetooth.devices.values.filter(d => d.connected)
    readonly property bool connected: connectedDevices.length > 0

    readonly property string icon: !enabled ? "bluetooth-off" : connected ? "bluetooth-connected" : "bluetooth"

    // Kontrol merkezinde Bluetooth bloğunun alt yazısı
    readonly property string summary: {
        if (!available)
            return "Yok";
        if (!enabled)
            return "Kapalı";
        if (connectedDevices.length === 1)
            return connectedDevices[0].name;
        if (connectedDevices.length > 1)
            return connectedDevices.length + " cihaz";
        return "Açık";
    }

    // Eşleşmiş cihazlar (bağlı olanlar önce, sonra ada göre) ve çevrede görünen yeni cihazlar
    readonly property var pairedDevices: Bluetooth.devices.values.filter(d => d.paired || d.bonded).sort((a, b) => {
        if (a.connected !== b.connected)
            return a.connected ? -1 : 1;
        return a.name.localeCompare(b.name);
    })
    readonly property var nearbyDevices: Bluetooth.devices.values.filter(d => !d.paired && !d.bonded && d.deviceName !== "")

    function setEnabled(on) {
        if (adapter)
            adapter.enabled = on;
    }

    // Bluetooth sayfası açıkken çevredeki cihazlar aranır. Eşleşirken arama durur (arama sürerken
    // eşleşme ve bağlantı sık sık "meşgul" hatası veriyor); eşleşme bitince sayfa açıksa yeniden başlar.
    property bool discoveryWanted: false

    function setDiscovering(on) {
        discoveryWanted = on;
        if (adapter && adapter.enabled)
            adapter.discovering = on;
    }

    // Eşleşmiş cihaza bağlan ya da bağlantıyı kes; yeni cihazı eşleştir
    function activate(device) {
        if (device.paired || device.bonded) {
            if (device.connected)
                device.disconnect();
            else
                device.connect();
        } else {
            // Eşleşince bağlanılsın diye cihaz güvenilir işaretlenir (aşağıdaki Connections)
            if (adapter && adapter.discovering)
                adapter.discovering = false;
            device.trusted = true;
            device.pair();
        }
    }

    function setDiscoverable(on) {
        if (adapter)
            adapter.discoverable = on;
    }

    // Cihaz türünün Türkçe adı (ayrıntı sayfası)
    function typeName(device) {
        switch (iconFor(device)) {
        case "headphones":
            return "Kulaklık";
        case "speaker":
            return "Hoparlör";
        case "mouse":
            return "Fare";
        case "keyboard":
            return "Klavye";
        case "smartphone":
            return "Telefon";
        case "gamepad-2":
            return "Oyun kumandası";
        case "laptop":
            return "Bilgisayar";
        default:
            return "Bluetooth cihazı";
        }
    }

    // Cihaz türüne göre simge (BlueZ "audio-headset", "input-mouse" gibi adlar veriyor)
    function iconFor(device) {
        const name = device?.icon ?? "";
        if (/audio-head|headphone/.test(name))
            return "headphones";
        if (/audio|speaker/.test(name))
            return "speaker";
        if (/mouse/.test(name))
            return "mouse";
        if (/keyboard/.test(name))
            return "keyboard";
        if (/phone/.test(name))
            return "smartphone";
        if (/gaming|joystick/.test(name))
            return "gamepad-2";
        if (/computer/.test(name))
            return "laptop";
        return "bluetooth";
    }

    // Yeni eşleşen cihaza hemen bağlan
    Instantiator {
        model: Bluetooth.devices

        delegate: Connections {
            required property var modelData
            target: modelData

            function onPairingChanged() {
                if (!modelData.pairing && root.discoveryWanted)
                    discoveryResume.restart();
            }

            function onPairedChanged() {
                if (!modelData.paired)
                    return;
                // "Şu kodu cihazda yaz" gibi gösterilenler eşleşince kalkar
                root.requests = root.requests.filter(r => r.device !== modelData.dbusPath);
                if (!modelData.connected)
                    modelData.connect();
            }
        }
    }

    // ---------- Eşleşme yardımcısı (scripts/bt_agent.py) ----------
    // BlueZ eşleşirken kod onayı, PIN ya da izin isterse soru buraya gelir; kontrol merkezi Bluetooth
    // sayfasında gösterir (BluetoothPrompt.qml). Yardımcı olmadan onay isteyen cihazlar ya hiç eşleşmiyor
    // ya da anahtar saklanmadan yarım eşleşiyordu (plan: Sorun 52, 79).
    // İstek: { id, kind, device (D-Bus yolu), name, address, code, entered, uuid }; kind'lar bt_agent.py'de.
    property var requests: []
    readonly property var request: requests.length > 0 ? requests[0] : null
    property bool agentReady: false
    property int agentFailures: 0

    // Yanıt: ok (kabul/ret), value (PIN ya da kod). Yalnızca gösterilenler (show-…) için yanıt gitmez.
    function answer(req, ok, value) {
        if (req.id > 0 && agent.running)
            agent.write(JSON.stringify({
                id: req.id,
                ok: ok,
                value: value ?? ""
            }) + "\n");
        requests = requests.filter(r => r !== req);
    }

    function deviceFor(req) {
        return Bluetooth.devices.values.find(d => d.dbusPath === req?.device || d.address === req?.address) ?? null;
    }

    function handleAgent(line) {
        let msg;
        try {
            msg = JSON.parse(line);
        } catch (e) {
            console.warn("bt_agent:", line);
            return;
        }
        switch (msg.kind) {
        case "ready":
            agentReady = true;
            agentFailures = 0;
            return;
        case "error":
            agentReady = false;
            console.warn("Bluetooth eşleşme yardımcısı:", msg.message);
            return;
        case "cancel":
            // BlueZ vazgeçti (süre doldu, cihaz gitti, eşleşme başka yerden bitti)
            requests = [];
            return;
        }
        // Aynı cihazın gösterilen kodu güncellenir (yazılan hane sayısı); yenisi sona eklenir
        const rest = msg.kind.startsWith("show-") ? requests.filter(r => !(r.device === msg.device && r.kind === msg.kind)) : requests;
        requests = rest.concat([msg]);
        Ui.controlCenterOpenRequested("bluetooth");
    }

    // Eşleşmemiş bir cihaz servise bağlanmak isterse ne istediği (Türkçe)
    function serviceName(uuid) {
        const short = (uuid ?? "").slice(4, 8).toLowerCase();
        const names = {
            "110a": "ses gönderme",
            "110b": "ses",
            "110c": "medya kumandası",
            "110e": "medya kumandası",
            "111e": "telefon görüşmesi",
            "111f": "telefon görüşmesi",
            "1124": "klavye ya da fare",
            "1105": "dosya gönderme",
            "1106": "dosya aktarma",
            "112f": "rehber",
            "1132": "mesajlar",
            "1116": "internet paylaşımı",
            "1115": "internet paylaşımı"
        };
        return names[short] ?? "";
    }

    function startAgent() {
        if (available && !agent.running)
            agent.running = true;
    }

    Component.onCompleted: startAgent()
    onAvailableChanged: startAgent()

    Process {
        id: agent

        // DESK_PYTHON: dbus-next'li Python (desk/nix/home.nix). Elle çalıştırırken yoksa sistemdeki python3.
        command: [Quickshell.env("DESK_PYTHON") || "python3", Quickshell.shellPath("scripts/bt_agent.py")]
        stdinEnabled: true
        stdout: SplitParser {
            onRead: data => root.handleAgent(data)
        }
        stderr: SplitParser {
            onRead: data => console.warn("bt_agent:", data)
        }
        onExited: code => {
            root.agentReady = false;
            root.requests = [];
            root.agentFailures++;
            // Sürekli düşüyorsa (dbus-next yok gibi) dakikada bir dene
            agentRetry.interval = root.agentFailures > 3 ? 60000 : 3000;
            agentRetry.restart();
        }
    }

    Timer {
        id: agentRetry
        onTriggered: root.startAgent()
    }

    // Eşleşmeden sonra bağlantıya fırsat verip aramayı yeniden başlat
    Timer {
        id: discoveryResume
        interval: 5000
        onTriggered: {
            if (root.discoveryWanted && root.adapter?.enabled)
                root.adapter.discovering = true;
        }
    }
}
