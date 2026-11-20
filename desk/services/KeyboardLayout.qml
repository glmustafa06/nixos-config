pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

// Etkin klavye düzeni: barda "TR" gibi iki harf. Kilit ekranı Caps Lock'u da buradan okur.
Singleton {
    id: root

    property string code: "TR"
    property bool capsLock: false

    // Caps Lock için Hyprland haber vermiyor; kilit ekranı tuşa basılınca yeniden sorar
    function refresh() {
        devices.running = true;
    }

    // Hyprland düzen adını uzun yazar ("Turkish"); bilinenleri kısalt
    readonly property var names: ({
            "Turkish": "TR",
            "Turkish (F)": "F",
            "English (US)": "US",
            "English (US, intl., with dead keys)": "US",
            "English (UK)": "UK",
            "German": "DE"
        })

    function setFromName(layout) {
        code = names[layout] ?? layout.slice(0, 2).toUpperCase();
    }

    // Açılışta: ana klavyenin etkin düzenini sor
    Process {
        id: devices
        command: ["hyprctl", "devices", "-j"]
        running: true
        environment: ({ "LC_ALL": "C" })

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const keyboards = JSON.parse(text).keyboards ?? [];
                    const main = keyboards.find(k => k.main) ?? keyboards[0];
                    if (main?.active_keymap)
                        root.setFromName(main.active_keymap);
                    root.capsLock = main?.capsLock === true;
                } catch (e) {
                    console.warn("KeyboardLayout: hyprctl çıktısı okunamadı:", e);
                }
            }
        }
    }

    // Sonra: düzen değiştikçe Hyprland haber veriyor. Olay verisi: "klavye-adı,düzen-adı"
    Connections {
        target: Hyprland

        function onRawEvent(event) {
            if (event.name !== "activelayout")
                return;
            root.setFromName(event.data.split(",").slice(1).join(","));
        }
    }
}
