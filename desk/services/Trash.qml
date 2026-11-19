pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Çöp kutusu (freedesktop: ~/.local/share/Trash). Dolphin'in çöp kutusuyla aynı yer.
// Dolu mu boş mu, dock görünürken ara ara bakılır (dosya sistemi haber vermiyor).
Singleton {
    id: root

    readonly property string dir: (Quickshell.env("XDG_DATA_HOME") || Quickshell.env("HOME") + "/.local/share") + "/Trash"
    property bool full: false

    function refresh() {
        if (!check.running)
            check.running = true;
    }

    function open() {
        Commands.open(["dolphin", "trash:/"]);
    }

    // Kalıcı olarak siler (geri alınamaz; dock'ta onay alt menüsünden sonra çağrılır)
    function empty() {
        Commands.run(["sh", "-c", 'T="$1"; for d in files info expunged; do [ -d "$T/$d" ] && find "$T/$d" -mindepth 1 -delete; done; rm -f "$T/directorysizes"', "sh", dir], () => root.refresh());
    }

    Process {
        id: check
        command: ["find", root.dir + "/files", "-mindepth", "1", "-maxdepth", "1", "-print", "-quit"]
        stdout: StdioCollector {
            onStreamFinished: root.full = text.trim() !== ""
        }
    }

    Component.onCompleted: refresh()
}
