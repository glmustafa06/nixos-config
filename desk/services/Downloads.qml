pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// İndirilenler klasörü ve içindeki son dosyalar (dock'taki İndirilenler menüsü).
// Klasörün yeri ~/.config/user-dirs.dirs'ten okunur (Türkçe kurulumda "İndirilenler" olabilir).
Singleton {
    id: root

    readonly property string home: Quickshell.env("HOME")
    property string dir: home + "/Downloads"

    // En yeniden eskiye: [{ name, path, isDir }]
    property var files: []
    readonly property int maxFiles: 10

    function refresh() {
        if (!list.running)
            list.running = true;
    }

    function open(path) {
        Commands.open(["xdg-open", path]);
    }
    function openFolder() {
        Commands.open(["xdg-open", dir]);
    }

    // Dosya türüne göre simge adı (FileKinds: arama da aynısını kullanır)
    function iconFor(file) {
        return FileKinds.iconFor(file.name, file.isDir);
    }

    FileView {
        path: root.home + "/.config/user-dirs.dirs"
        printErrors: false
        onLoaded: {
            const match = text().match(/^XDG_DOWNLOAD_DIR="(.*)"\s*$/m);
            if (match)
                root.dir = match[1].replace("$HOME", root.home);
            root.refresh();
        }
        onLoadFailed: root.refresh()
    }

    // Satır başına: değişme zamanı, tür (d: klasör), ad. Gizli dosyalar atlanır.
    Process {
        id: list
        command: ["find", root.dir, "-mindepth", "1", "-maxdepth", "1", "-not", "-name", ".*", "-printf", "%T@\t%y\t%f\n"]
        stdout: StdioCollector {
            onStreamFinished: {
                const rows = text.split("\n").filter(line => line !== "").map(line => {
                    const [time, type, ...rest] = line.split("\t");
                    const name = rest.join("\t");
                    return {
                        time: parseFloat(time) || 0,
                        name: name,
                        path: root.dir + "/" + name,
                        isDir: type === "d"
                    };
                });
                rows.sort((a, b) => b.time - a.time);
                root.files = rows.slice(0, root.maxFiles);
            }
        }
    }
}
