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

    // Dosyaları çöpe taşır (dock'taki çöp kutusuna bırakılınca). gio, freedesktop kuralıyla taşır:
    // Dolphin'in çöp kutusunda görünür, oradan geri yüklenebilir. Başka diskteki dosyalar o diskin
    // kendi çöp klasörüne gider.
    function trashFiles(paths) {
        if (paths.length === 0)
            return;
        Commands.run(["gio", "trash", "--"].concat(paths), (code, out, err) => {
            root.refresh();
            if (code !== 0) {
                const count = paths.length === 1 ? paths[0].split("/").pop() : `${paths.length} öğe`;
                Notifications.notify("Çöp kutusu", `${count} çöpe taşınamadı`, err.trim().split("\n").pop() || "gio trash çalışmadı.", "trash-2", 1, null, "trash");
            }
        });
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
