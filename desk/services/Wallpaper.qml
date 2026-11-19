pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.theme

// Duvar kâğıdı: hangi resim, hangi klasörden seçilir.
// Seçim ~/.local/state/desk/wallpaper.json dosyasında saklanır; kilit ekranı da buradan okur.
// Resim değişince scripts/colors.sh çalışır: vurgu rengi ve barın görünümü kendiliğinden güncellenir.
//
// Klasör: wallpaper.json'daki "directory" yazılıysa o; yoksa şu anki duvar kâğıdının klasörü;
// o da yoksa Resimler içinde "Duvar Kağıtları" / "Wallpapers" gibi bir klasör, en son Resimler.
Singleton {
    id: root

    readonly property string current: store.path !== "" ? store.path : Colors.source
    readonly property string directory: store.directory !== "" ? store.directory : detectedDirectory
    property string detectedDirectory: ""

    // Klasördeki resimler (tam yol, ada göre sıralı). refresh() ile okunur.
    property var images: []
    property bool loading: false
    // colors.sh çalışıyor mu
    readonly property bool coloring: colors.running

    // Aynı resim yeniden seçilirse yalnızca renkler yeniden üretilir
    function set(path) {
        if (!path)
            return;
        store.path = path;
        colors.image = path;
        // Önceki çalışma bitmeden yenisi seçilirse sonuncusu kazansın
        colors.running = false;
        colors.running = true;
    }

    // Seçici açılınca: klasörü bul (gerekirse) ve resimleri listele
    function refresh() {
        if (directory === "") {
            detect.running = true;
            return;
        }
        list();
    }

    function list() {
        if (directory === "")
            return;
        loading = true;
        lister.command = ["find", "-L", directory, "-maxdepth", "1", "-type", "f", "(", "-iname", "*.jpg", "-o", "-iname", "*.jpeg", "-o", "-iname", "*.png", "-o", "-iname", "*.webp", ")"];
        lister.running = true;
    }

    function openFolder() {
        if (directory !== "")
            Commands.open(["xdg-open", directory]);
    }

    // Yoldan resim adresi: boşluk, "#" ve Türkçe harfler adresi bozmasın
    function fileUrl(path) {
        return path ? "file://" + path.split("/").map(encodeURIComponent).join("/") : "";
    }

    function dirname(path) {
        const i = path.lastIndexOf("/");
        return i > 0 ? path.slice(0, i) : "";
    }
    function basename(path) {
        return path.slice(path.lastIndexOf("/") + 1);
    }

    // Klasörü bul: şu anki duvar kâğıdının klasörü ya da Resimler'deki bilinen adlar
    Process {
        id: detect

        environment: ({
                "CURRENT": root.current
            })
        command: ["sh", "-c", `
            if [ -n "$CURRENT" ] && [ -f "$CURRENT" ]; then dirname "$CURRENT"; exit 0; fi
            pics="$(. "$HOME/.config/user-dirs.dirs" 2>/dev/null; echo "$XDG_PICTURES_DIR")"
            [ -n "$pics" ] && [ "$pics" != "$HOME" ] || pics="$HOME/Pictures"
            for d in "$pics/Duvar Kağıtları" "$pics/Duvar kağıtları" "$pics/Duvar kâğıtları" "$pics/Wallpapers" "$pics/wallpapers" "$HOME/Wallpapers" "$pics"; do
                if [ -d "$d" ]; then echo "$d"; exit 0; fi
            done
            echo "$pics"`]
        stdout: StdioCollector {
            onStreamFinished: {
                root.detectedDirectory = text.trim();
                root.list();
            }
        }
    }

    Process {
        id: lister

        stdout: StdioCollector {
            onStreamFinished: {
                root.images = text.split("\n").filter(line => line !== "").sort((a, b) => a.localeCompare(b, "tr"));
                root.loading = false;
            }
        }
        onExited: code => {
            if (code !== 0)
                root.loading = false;
        }
    }

    Process {
        id: colors

        property string image: ""
        command: ["bash", Quickshell.shellPath("scripts/colors.sh"), image]
        stderr: StdioCollector {
            onStreamFinished: {
                if (text.trim() !== "")
                    console.warn("Wallpaper: colors.sh:", text.trim());
            }
        }
    }

    FileView {
        path: Quickshell.env("HOME") + "/.local/state/desk/wallpaper.json"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        // Dosya yoksa ilk seçimde oluşur
        onAdapterUpdated: writeAdapter()

        JsonAdapter {
            id: store
            property string path: ""
            property string directory: ""
        }
    }
}
