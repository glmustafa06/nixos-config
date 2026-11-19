pragma Singleton

import QtQuick
import Quickshell

// Pano geçmişi (cliphist). Kopyalananları cliphist'in arka plan servisleri kaydeder
// (home.nix → services.cliphist); burada yalnızca okunur, geri kopyalanır, silinir.
//
// Her kayıt: { line (cliphist'in satırı: "<no>\t<önizleme>"), id, text, image (bool), info }
// Resimlerin küçük hâli ilk gösterilişte $XDG_RUNTIME_DIR/desk-clipboard içine çıkarılır
// (bellekte duran geçici klasör; kapanınca silinir, diske yazılmaz).
Singleton {
    id: root

    property var entries: []
    property bool loading: false
    property bool available: true   // cliphist kurulu ve çalışıyor mu
    // Küçük resimler: no → dosya yolu
    property var thumbs: ({})
    readonly property string thumbDir: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/desk-clipboard"

    function refresh() {
        loading = true;
        Commands.run(["cliphist", "list"], (code, out) => {
            root.loading = false;
            root.available = code === 0;
            root.entries = code === 0 ? out.split("\n").filter(line => line.includes("\t")).map(parse) : [];
        });
    }

    function parse(line) {
        const tab = line.indexOf("\t");
        const preview = line.slice(tab + 1);
        // "[[ binary data 123 KiB png 1920x1080 ]]"
        const binary = preview.match(/^\[\[ binary data (.+) \]\]$/);
        const parts = binary ? binary[1].split(" ") : [];
        return {
            line: line,
            id: line.slice(0, tab),
            text: binary ? "" : preview,
            image: binary !== null && /^(png|jpe?g|gif|webp|bmp)$/.test(parts[2] ?? ""),
            // "PNG · 1920×1080 · 123 KiB"
            info: binary ? [(parts[2] ?? "").toUpperCase(), (parts[3] ?? "").replace("x", "×"), parts.slice(0, 2).join(" ")].filter(t => t !== "").join(" · ") : ""
        };
    }

    // Seçileni yeniden panoya koy
    function copy(entry) {
        Quickshell.execDetached(["sh", "-c", "printf '%s\\n' \"$1\" | cliphist decode | wl-copy", "sh", entry.line]);
    }

    function remove(entry) {
        entries = entries.filter(e => e.id !== entry.id);
        Quickshell.execDetached(["sh", "-c", "printf '%s\\n' \"$1\" | cliphist delete", "sh", entry.line]);
    }

    // Resmin küçük hâlini hazırla (bir kez); hazır olunca thumbs[no] dolar
    property var pending: ({})
    function requestThumb(entry) {
        if (!entry || !entry.image || thumbs[entry.id] || pending[entry.id])
            return;
        pending[entry.id] = true;
        const path = `${thumbDir}/${entry.id}`;
        Commands.run(["sh", "-c", "mkdir -p \"$(dirname \"$2\")\" && chmod 700 \"$(dirname \"$2\")\" && printf '%s\\n' \"$1\" | cliphist decode > \"$2\"", "sh", entry.line, path], code => {
            delete root.pending[entry.id];
            if (code !== 0)
                return;
            const map = Object.assign({}, root.thumbs);
            map[entry.id] = path;
            root.thumbs = map;
        });
    }
}
