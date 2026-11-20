pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Ayarlar: ~/nixos-config/desk-ayarlar.json (desk/nix/home.nix → DESK_SETTINGS).
// Ayarlar penceresi (modules/settings) yazar; desk'in her yeri buradan okur ve değişince anında uyar:
//   Settings.s.dock.iconSize, Settings.s.bar.seconds …
// Dosyada yalnızca varsayılandan farklı olanlar durur (git'te küçük ve okunur kalsın). Dosya elle
// değiştirilirse (ya da git'le geri alınırsa) desk onu da hemen görür. Bozuk dosya yok sayılır,
// desk varsayılanlarla çalışır; ilk değişiklikte doğru hâli yazılır.
//
// Ayrı bir modül (qs.settings): tema (Colors, Metrics) ve servisler bunu döngüye girmeden kullanır.
Singleton {
    id: root

    readonly property string path: Quickshell.env("DESK_SETTINGS") || Quickshell.env("HOME") + "/nixos-config/desk-ayarlar.json"

    // ---------- Varsayılanlar ----------
    // Süreler dakika; saatler gece yarısından beri dakika (1380 = 23:00).
    readonly property var defaults: ({
            appearance: {
                accent: "",                 // "" duvar kâğıdından; "#rrggbb" sabit renk
                barTone: "auto",            // auto (duvar kâğıdına göre) · dark · light
                reduceTransparency: false,  // cam daha koyu, bar daha örtücü
                reduceMotion: false         // pencere animasyonları kapalı, desk'inkiler kısa
            },
            windows: {
                gapsIn: 5,                  // iki pencere arası bunun iki katı
                gapsOut: 10,                // ekran kenarına
                rounding: 8,
                dimInactive: true,
                dimStrength: 0.15,
                shadow: true
            },
            bar: {
                // Sağdaki öğeler soldan sağa ve gizlenenler (kontrol merkezi ve saat gizlenemez)
                order: ["tray", "keyboard", "bluetooth", "sound", "battery", "wifi", "search", "controlcenter", "clock"],
                hidden: [],
                weekday: true,
                date: true,
                seconds: false,
                batteryPercent: true,
                menus: true                 // solda Pencere ve Düzen menüleri
            },
            dock: {
                pinned: null,               // null: eski dock.json'daki liste (DockApps)
                behavior: "smart",          // smart (pencere gelince gizlen) · always · autohide
                iconSize: 48,
                places: true,               // İndirilenler ve çöp kutusu
                badges: true,
                indicators: true
            },
            notifications: {
                popupSeconds: 5,
                hiddenApps: [],             // adada gösterilmeyenler (merkezde yine görünür)
                quietSchedule: false,       // her gün belli saatlerde rahatsız etme
                quietFrom: 1380,
                quietTo: 420
            },
            display: {
                nightTemperature: 4500,
                nightSchedule: false,
                nightFrom: 1260,
                nightTo: 420
            },
            power: {
                batteryLite: true,          // pilde 60 Hz, tek geçişli bulanıklık, kısa animasyonlar
                batteryDim: 3,              // 0: hiçbir zaman
                batteryLock: 5,
                batterySuspend: 15,
                acDim: 10,
                acLock: 15,
                acSuspend: 0,
                lidAction: "lock",          // lock (kilitle, pildeyse sonra uyu) · suspend (hemen uyu)
                lidSuspend: 15,             // kapak kapalıyken pilde kaç dakika sonra uyku (0: hiç)
                batteryCare: false          // şarjı erken durdur (services/PowerSettings.qml)
            },
            input: {
                layouts: ["tr"],
                layoutSwitch: "grp:alt_shift_toggle",
                repeatRate: 40,
                repeatDelay: 300,
                followMouse: true,
                pointerSpeed: 0,
                naturalScroll: false,
                tapToClick: true,
                disableWhileTyping: true
            },
            screenshot: {
                previewSeconds: 6,          // 0: önizleme yok
                fps: 60,
                cursor: true,
                audio: false
            },
            calendar: {
                reminder: 10                // yeni etkinlikte: -1 yok, 0 vaktinde, 10, 60, 1440 dk önce
            }
        })

    // ---------- Değerler ----------
    // Dosyadaki değişiklikler (yalnızca varsayılandan farklı olanlar)
    property var data: ({})
    // Varsayılanlarla birleşmiş hâli: her yer bunu okur
    readonly property var s: merge(defaults, data)
    // Dosya okundu mu (okunamadıysa da true: varsayılanlar geçerli)
    property bool ready: false

    // Sık kullanılanlar
    readonly property bool reduceTransparency: s.appearance.reduceTransparency
    readonly property bool reduceMotion: s.appearance.reduceMotion

    // ---------- Bardaki öğeler ----------
    // group: aynı gruptakiler bitişik, gruplar arasında biraz boşluk (macOS'taki gibi)
    readonly property var barItemInfo: ({
            tray: { name: "Uygulama simgeleri", detail: "Steam, Discord gibi", icon: "app-window", group: "tray" },
            keyboard: { name: "Klavye dili", detail: "", icon: "keyboard", group: "keyboard" },
            bluetooth: { name: "Bluetooth", detail: "", icon: "bluetooth", group: "status" },
            sound: { name: "Ses", detail: "", icon: "volume-2", group: "status" },
            battery: { name: "Pil", detail: "", icon: "battery-charging", group: "status" },
            wifi: { name: "Wi-Fi", detail: "", icon: "wifi", group: "status" },
            search: { name: "Arama", detail: "", icon: "search", group: "system" },
            controlcenter: { name: "Kontrol merkezi", detail: "Her zaman görünür", icon: "control-center", group: "system", fixed: true },
            clock: { name: "Saat", detail: "Her zaman görünür", icon: "clock", group: "clock", fixed: true }
        })

    // Kayıttaki sıra; bilinmeyenler atılır, eksikler (yeni eklenen öğeler) varsayılan yerlerine girer.
    // [{ id, shown }] soldan sağa
    readonly property var barItems: {
        const known = defaults.bar.order;
        const list = [];
        for (const id of s.bar.order) {
            if (known.includes(id) && !list.includes(id))
                list.push(id);
        }
        known.forEach((id, index) => {
            if (list.includes(id))
                return;
            // Varsayılan sırada kendinden önceki ilk öğenin arkasına
            const before = known.slice(0, index).reverse().find(other => list.includes(other));
            list.splice(before ? list.indexOf(before) + 1 : 0, 0, id);
        });
        return list.map(id => ({
                    id: id,
                    shown: barItemInfo[id].fixed === true || !s.bar.hidden.includes(id)
                }));
    }

    // ---------- Klavye düzenleri ----------
    readonly property var keyboardLayouts: [
        { id: "tr", name: "Türkçe Q", layout: "tr", variant: "" },
        { id: "tr-f", name: "Türkçe F", layout: "tr", variant: "f" },
        { id: "us", name: "İngilizce (ABD)", layout: "us", variant: "" },
        { id: "us-intl", name: "İngilizce (uluslararası)", layout: "us", variant: "intl" },
        { id: "gb", name: "İngilizce (Birleşik Krallık)", layout: "gb", variant: "" },
        { id: "de", name: "Almanca", layout: "de", variant: "" }
    ]

    // ---------- Okuma, yazma ----------
    function isObject(value) {
        return value !== null && typeof value === "object" && !Array.isArray(value);
    }

    function clone(value) {
        return value === undefined ? undefined : JSON.parse(JSON.stringify(value));
    }

    function equal(a, b) {
        return JSON.stringify(a) === JSON.stringify(b);
    }

    // Varsayılanın üstüne dosyadakini koy. Türü tutmayan değer (elle yanlış yazılmış) yok sayılır.
    function merge(base, over) {
        if (over === undefined)
            return base;
        if (isObject(base)) {
            if (!isObject(over))
                return base;
            const out = {};
            for (const key of Object.keys(base))
                out[key] = merge(base[key], over[key]);
            return out;
        }
        if (base === null)
            return over === null || Array.isArray(over) ? over : base;
        if (Array.isArray(base))
            return Array.isArray(over) ? over : base;
        return typeof over === typeof base ? over : base;
    }

    function defaultOf(path) {
        return path.split(".").reduce((node, key) => node?.[key], defaults);
    }

    function get(path) {
        return path.split(".").reduce((node, key) => node?.[key], s);
    }

    // set("dock.iconSize", 52): varsayılana dönünce dosyadan silinir
    function set(path, value) {
        const keys = path.split(".");
        if (defaultOf(path) === undefined) {
            console.warn(`Settings: bilinmeyen ayar ${path}`);
            return;
        }
        if (equal(get(path), value))
            return;
        const next = clone(data) ?? {};
        let node = next;
        for (const key of keys.slice(0, -1)) {
            if (!isObject(node[key]))
                node[key] = {};
            node = node[key];
        }
        const last = keys[keys.length - 1];
        if (equal(value, defaultOf(path)))
            delete node[last];
        else
            node[last] = clone(value);
        data = prune(next);
        saveTimer.restart();
    }

    // Bir bölümü (ya da hepsini: "") varsayılana döndür
    function reset(section) {
        if (section === "") {
            data = {};
        } else {
            const next = clone(data);
            delete next[section];
            data = next;
        }
        saveTimer.restart();
    }

    // Boş kalan bölümleri at
    function prune(node) {
        for (const key of Object.keys(node)) {
            if (isObject(node[key])) {
                prune(node[key]);
                if (Object.keys(node[key]).length === 0)
                    delete node[key];
            }
        }
        return node;
    }

    // Dosyanın metni (girintili; anahtarlar varsayılandaki sırayla)
    function serialize() {
        const ordered = (base, value) => {
            if (!isObject(value) || !isObject(base))
                return value;
            const out = {};
            for (const key of Object.keys(base)) {
                if (value[key] !== undefined)
                    out[key] = ordered(base[key], value[key]);
            }
            for (const key of Object.keys(value)) {
                if (out[key] === undefined)
                    out[key] = value[key];
            }
            return out;
        };
        return stringify(ordered(defaults, data), "") + "\n";
    }

    // JSON.stringify(…, null, 2) gibi; ama sayı ve yazılardan oluşan diziler tek satırda
    // ("order": ["search", "tray", …]): dosya kısa kalır, git farkı okunur
    function stringify(value, indent) {
        if (Array.isArray(value)) {
            if (value.every(v => v === null || typeof v !== "object"))
                return "[" + value.map(v => JSON.stringify(v)).join(", ") + "]";
            const inner = indent + "  ";
            return "[\n" + value.map(v => inner + stringify(v, inner)).join(",\n") + "\n" + indent + "]";
        }
        if (isObject(value)) {
            const keys = Object.keys(value);
            if (keys.length === 0)
                return "{}";
            const inner = indent + "  ";
            return "{\n" + keys.map(key => inner + JSON.stringify(key) + ": " + stringify(value[key], inner)).join(",\n") + "\n" + indent + "}";
        }
        return JSON.stringify(value);
    }

    // En son yazılan ya da okunan metin: kendi yazdığımız dosya geri gelince yeniden okunmasın
    property string lastText: ""

    function parse(text) {
        if (text === lastText)
            return;
        lastText = text;
        if (text.trim() === "") {
            data = {};
            return;
        }
        try {
            const parsed = JSON.parse(text);
            data = isObject(parsed) ? parsed : {};
        } catch (e) {
            console.warn(`Settings: ${path} okunamadı (${e}); varsayılanlar kullanılıyor`);
        }
    }

    function save() {
        const text = serialize();
        if (text === lastText)
            return;
        lastText = text;
        file.setText(text);
    }

    // Sürgü sürüklenirken her adımda yazılmasın
    Timer {
        id: saveTimer
        interval: 400
        onTriggered: root.save()
    }

    // İlk okuma beklenerek (renkler ve ölçüler ilk karede doğru olsun; dosya küçük)
    Component.onCompleted: {
        root.parse(file.text());
        root.ready = true;
    }

    FileView {
        id: file
        path: root.path
        // Açılışta beklenir: renkler ve ölçüler ilk karede doğru olsun (dosya küçük)
        blockLoading: true
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            root.parse(text());
            root.ready = true;
        }
        onLoadFailed: error => {
            if (error === FileViewError.FileNotFound) {
                root.lastText = "";
                root.data = {};
            }
            root.ready = true;
        }
        onSaveFailed: error => console.warn(`Settings: ${root.path} yazılamadı (${error})`)
    }
}
