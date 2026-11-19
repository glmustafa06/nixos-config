pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower

// Aramanın beyni: ne yazılınca neyin çıkacağı ve seçilince ne olacağı.
//
//   uygulamalar        .desktop kayıtları (adı, türü, anahtar kelimeleri)
//   ayarlar, işlemler  kontrol merkezinin sayfaları, gece ışığı, güç modu, kilitle …
//   hesap makinesi     işlem yazılınca kendiliğinden (Calculator.qml)
//   dosyalar           "/" ile başlayınca ev klasöründe (fd)
//   pano               Super+V ya da "Pano" ile açılan ayrı hâl (mode: "clipboard", Clipboard.qml)
//
// Eşleşme harf atlayarak ve Türkçe harflere duyarsız ("ozel" → "Özelleştirme", "zn" → "Zen").
// Sık açılanlar öne geçer; kayıt ~/.local/state/desk/search.json dosyasında.
//
// Her sonuç: { id, kind, title, subtitle, icon (çizgi simge) ya da image (dosya), tag, hint, run, runAlt }
// hint: yalnızca seçili satırda alt yazının yanında görünen kısayol ipucu
Singleton {
    id: root

    readonly property string home: Quickshell.env("HOME")
    readonly property int maxResults: 8

    // ---------- Karşılaştırma ----------
    // Küçük harf ve şapkasız: "İnternet Ayarları" → "internet ayarlari"
    function fold(text) {
        const map = {
            "ç": "c",
            "ğ": "g",
            "ı": "i",
            "ö": "o",
            "ş": "s",
            "ü": "u",
            "â": "a",
            "î": "i",
            "û": "u"
        };
        return String(text ?? "").toLowerCase().replace(/\u0307/g, "").replace(/[çğıöşüâîû]/g, c => map[c]);
    }

    // 0: eşleşmedi. Tam eşleşme > baştan > kelime başından > içinde > harf atlayarak.
    // Harf atlayarak eşleşme yalnızca adlarda (fuzzy); uzun açıklamalarda her şey "eşleşirdi".
    function matchScore(q, target, fuzzy) {
        if (q === "" || target === "")
            return 0;
        if (target === q)
            return 100;
        if (target.startsWith(q))
            return 90;
        if (target.split(/[\s\-_.\/]+/).some(w => w.startsWith(q)))
            return 75;
        if (target.includes(q))
            return 60;
        if (!fuzzy)
            return 0;
        let from = 0, last = -1, gaps = 0, starts = 0;
        for (const ch of q) {
            const found = target.indexOf(ch, from);
            if (found < 0)
                return 0;
            if (last >= 0)
                gaps += found - last - 1;
            if (found === 0 || /[\s\-_.]/.test(target[found - 1]))
                starts++;
            last = found;
            from = found + 1;
        }
        return Math.max(5, 40 - gaps * 2 + starts * 6);
    }

    // Bir öğenin en iyi alanı (ad tam ağırlıkta, tür ve anahtar kelimeler daha az).
    // Sorguda birden çok kelime varsa her biri bir alanda eşleşmeli.
    function itemScore(q, keys) {
        const weights = [1, 0.7, 0.65, 0.5];
        const best = text => {
            let score = 0;
            keys.forEach((key, i) => score = Math.max(score, matchScore(text, key, i === 0) * (weights[i] ?? 0.5)));
            return score;
        };
        const whole = best(q);
        const words = q.split(/\s+/).filter(w => w !== "");
        if (whole > 0 || words.length < 2)
            return whole;
        let total = 0;
        for (const w of words) {
            const s = best(w);
            if (s === 0)
                return 0;
            total += s;
        }
        return total / words.length * 0.9;
    }

    // ---------- Sık kullanılanlar ----------
    function usageBoost(id) {
        const u = store.usage[id];
        if (!u)
            return 0;
        const days = (Date.now() - u.last) / 86400000;
        return Math.min(u.count, 30) * 1.2 + (days < 1 ? 6 : days < 7 ? 3 : 0);
    }

    function recordUse(id) {
        const usage = Object.assign({}, store.usage);
        const old = usage[id] ?? {
            count: 0,
            last: 0
        };
        usage[id] = {
            count: old.count + 1,
            last: Date.now()
        };
        store.usage = usage;
    }

    // ---------- Kaynaklar ----------
    readonly property var appItems: DesktopEntries.applications.values.filter(e => !e.noDisplay).map(e => ({
                id: "app:" + e.id,
                kind: "app",
                title: e.name,
                subtitle: e.genericName || e.comment || "",
                image: DockApps.iconOf(e.id),
                tag: "Uygulama",
                keys: [fold(e.name), fold(e.genericName), fold(Array.from(e.keywords ?? []).join(" ")), fold(e.id)],
                run: () => Commands.launch(e)
            }))

    // Ayarlar ve hızlı işlemler. Geri alınamayanlar (yeniden başlat, kapat, oturumu kapat)
    // doğrudan yapılmaz; onay isteyen güç sayfası açılır.
    function setting(id, title, subtitle, icon, keywords, run, tag) {
        return {
            id: id,
            kind: "setting",
            title: title,
            subtitle: subtitle,
            icon: icon,
            tag: tag ?? "Ayar",
            keys: [fold(title), fold(subtitle), fold(keywords)],
            run: run
        };
    }

    readonly property var settingItems: {
        const list = [
            setting("cc:wifi", "Wi-Fi", "Ağlar ve bağlantı ayrıntıları", "wifi", "wifi kablosuz ag internet network wlan sifre", () => Ui.controlCenterRequested("wifi")),
            setting("cc:bluetooth", "Bluetooth", "Cihazlar ve eşleştirme", "bluetooth", "bluetooth kulaklik cihaz eslestir", () => Ui.controlCenterRequested("bluetooth")),
            setting("cc:sound", "Ses", "Çıkış, mikrofon ve uygulamalar", "volume-2", "ses hoparlor kulaklik mikrofon cikis giris volume easyeffects", () => Ui.controlCenterRequested("sound")),
            setting("cc:battery", "Pil", "Doluluk, kalan süre, güç modu", "zap", "pil batarya sarj guc enerji", () => Ui.controlCenterRequested("battery")),
            setting("cc:main", "Kontrol merkezi", "Hızlı ayarlar", "control-center", "kontrol merkezi hizli ayarlar parlaklik ekran", () => Ui.controlCenterRequested("main")),
            setting("act:nightlight", QuickSettings.nightLight ? "Gece ışığını kapat" : "Gece ışığını aç", "Ekran rengi sıcak", "sun-medium", "gece isigi mavi isik sicak renk night light", () => QuickSettings.setNightLight(!QuickSettings.nightLight), "İşlem"),
            setting("act:dnd", QuickSettings.doNotDisturb ? "Rahatsız etmeyi kapat" : "Rahatsız etmeyi aç", "Bildirimleri sustur", "moon", "rahatsiz etme bildirim sessiz odak dnd", () => QuickSettings.setDoNotDisturb(!QuickSettings.doNotDisturb), "İşlem")
        ];
        for (const mode of PowerMode.modes) {
            if (mode.profile === PowerProfile.Performance && !PowerMode.hasPerformance)
                continue;
            list.push(setting("power:" + mode.name, "Güç modu: " + mode.name, mode.detail, mode.icon, "guc modu enerji pil profil " + fold(mode.name), () => PowerMode.set(mode.profile), "İşlem"));
        }
        for (const layout of ["dwindle", "scrolling", "monocle"]) {
            list.push(setting("layout:" + layout, "Düzen: " + layout, "Bu alandaki pencerelerin düzeni", "columns-3", "duzen layout pencere " + layout, () => WindowManager.setLayout(layout), "İşlem"));
        }
        list.push(setting("act:lock", "Kilitle", "Ekranı kilitle", "lock", "kilitle kilit ekran lock", () => Quickshell.execDetached(["loginctl", "lock-session"]), "İşlem"));
        list.push(setting("act:suspend", "Uyku", "Kilitleyip uyut", "moon", "uyku uyut askiya al suspend sleep", () => Quickshell.execDetached(["sh", "-c", "loginctl lock-session && sleep 1 && systemctl suspend"]), "İşlem"));
        list.push(setting("act:reboot", "Yeniden başlat…", "Onay ister", "rotate-ccw", "yeniden baslat restart reboot", () => Ui.controlCenterRequested("session"), "İşlem"));
        list.push(setting("act:poweroff", "Bilgisayarı kapat…", "Onay ister", "power", "kapat bilgisayari kapat shutdown power off", () => Ui.controlCenterRequested("session"), "İşlem"));
        list.push(setting("act:logout", "Oturumu kapat…", "Onay ister", "log-out", "oturumu kapat cikis logout", () => Ui.controlCenterRequested("session"), "İşlem"));
        list.push(setting("act:wallpaper", "Duvar kâğıdı", "Duvar kâğıdını değiştir", "image", "duvar kagidi arka plan wallpaper resim", () => Ui.wallpaperRequested()));
        list.push(setting("act:clipboard", "Pano", "Kopyalananların geçmişi", "clipboard-list", "pano kopyala gecmis clipboard yapistir", () => Ui.clipboardRequested()));
        list.push(setting("act:screenshot", "Ekran görüntüsü", "Bir alan seç; panoya ve Resimler'e", "maximize", "ekran goruntusu screenshot alan kes", () => Quickshell.execDetached(["sh", "-c", "sleep 0.3; exec \"$1\" region", "sh", Quickshell.shellPath("scripts/screenshot.sh")]), "İşlem"));
        return list;
    }

    // ---------- Arama ----------
    property string query: ""
    // "search": uygulamalar, ayarlar, hesap, dosyalar; "clipboard": pano geçmişi
    property string mode: "search"

    readonly property bool fileMode: query.startsWith("/")
    readonly property string fileTerm: fileMode ? query.slice(1).trim() : ""

    readonly property var results: {
        const q = fold(query.trim());
        if (mode === "clipboard")
            return clipboardResultsFor(q);
        if (fileMode)
            return fileResultsFor(fileTerm);

        // Boşken: son kullanılanlar; hiç yoksa dock'taki uygulamalar
        if (q === "") {
            const used = appItems.concat(settingItems).filter(item => store.usage[item.id]).sort((a, b) => usageBoost(b.id) - usageBoost(a.id));
            if (used.length > 0)
                return used.slice(0, 6);
            return DockApps.pinnedKeys.map(key => appItems.find(item => item.id === "app:" + key)).filter(item => item).slice(0, 6);
        }

        const list = [];
        if (Calculator.looksLikeMath(query)) {
            const value = Calculator.evaluate(query);
            if (value !== null) {
                const text = Calculator.format(value);
                list.push({
                    id: "calc",
                    kind: "calc",
                    title: text,
                    subtitle: query.trim().replace(/^=/, ""),
                    hint: "Enter: kopyala",
                    icon: "equal",
                    tag: "Hesap",
                    run: () => Quickshell.execDetached(["wl-copy", "--", text])
                });
            }
        }

        const scored = [];
        for (const item of appItems.concat(settingItems)) {
            const score = itemScore(q, item.keys);
            if (score > 0)
                scored.push({
                    item: item,
                    score: score + usageBoost(item.id)
                });
        }
        scored.sort((a, b) => b.score - a.score);
        // En iyisinin çok gerisinde kalanlar gösterilmez (gürültü olmasın)
        const floor = scored.length > 0 ? Math.max(12, scored[0].score * 0.35) : 0;
        for (const s of scored.filter(s => s.score >= floor).slice(0, maxResults - list.length))
            list.push(s.item);

        if (list.length === 0) {
            list.push({
                id: "hint",
                kind: "hint",
                title: "Sonuç yok",
                subtitle: "Dosya aramak için başına / koy: /" + query.trim(),
                icon: "search",
                enabled: false
            });
        }
        return list;
    }

    // Seçilen sonucu çalıştır. alt: Ctrl+Enter (dosyada: klasöründe göster)
    function activate(item, alt) {
        if (!item || item.enabled === false)
            return;
        if (item.kind !== "calc" && item.kind !== "hint" && item.kind !== "clip")
            recordUse(item.id);
        if (alt && item.runAlt)
            item.runAlt();
        else if (item.run)
            item.run();
    }

    // ---------- Pano ----------
    // Hepsi döner (en yenisi başta); arama penceresi 8'ini gösterir, oklar ve tekerlek kaydırır.
    // Birden çok kelime yazılırsa hepsi geçmeli.
    function clipboardResultsFor(q) {
        if (!Clipboard.available) {
            return [
                {
                    id: "hint",
                    kind: "hint",
                    title: "Pano geçmişi okunamadı",
                    subtitle: "cliphist çalışmıyor (README → Pano)",
                    icon: "clipboard-list",
                    enabled: false
                }
            ];
        }
        const words = q.split(/\s+/).filter(w => w !== "");
        const items = [];
        for (const entry of Clipboard.entries) {
            const haystack = fold(entry.image ? "resim " + entry.info : entry.text);
            if (words.some(w => !haystack.includes(w)))
                continue;
            const link = /^https?:\/\/\S+$/.test(entry.text.trim());
            items.push({
                id: "clip:" + entry.id,
                kind: "clip",
                entry: entry,
                title: entry.image ? "Resim" : entry.text.trim().replace(/\s+/g, " "),
                subtitle: entry.image ? entry.info : "",
                hint: "Enter: kopyala · Delete: sil",
                icon: entry.image ? "image" : link ? "link" : "clipboard-list",
                tag: entry.image ? "Resim" : link ? "Bağlantı" : "Metin",
                run: () => Clipboard.copy(entry)
            });
        }
        if (items.length === 0) {
            return [
                {
                    id: "hint",
                    kind: "hint",
                    title: Clipboard.loading ? "Yükleniyor…" : words.length > 0 ? "Eşleşen yok" : "Pano boş",
                    subtitle: words.length > 0 || Clipboard.loading ? "" : "Kopyaladıkların burada birikir",
                    icon: "clipboard-list",
                    enabled: false
                }
            ];
        }
        return items;
    }

    // ---------- Dosyalar (fd) ----------
    property var files: []          // fd'nin son çıktısı: ["/home/…/a.pdf", "/home/…/klasör/"]
    property string filesFor: ""    // files hangi arama için
    property bool searchingFiles: false

    onFileTermChanged: {
        if (fileTerm.length >= 2)
            fileTimer.restart();
        else
            fileTimer.stop();
    }

    // Yazarken her harfte değil, kısa bir duraklamada aranır
    Timer {
        id: fileTimer
        interval: 160
        onTriggered: root.startFileSearch(root.fileTerm)
    }

    // Türkçe harfe duyarsız desen: "numerik" → "N[uü]mer[iıİI]k" gibi
    function turkishPattern(word) {
        const classes = {
            "c": "[cçÇ]",
            "g": "[gğĞ]",
            "i": "[iıİI]",
            "o": "[oöÖ]",
            "s": "[sşŞ]",
            "u": "[uüÜ]"
        };
        return fold(word).replace(/[.*+?^${}()|[\]\\]/g, "\\$&").replace(/[cgious]/g, c => classes[c]);
    }

    // Her aramanın bir sırası var; yazmaya devam edildiyse eski aramanın sonucu atılır
    property int fileSearchId: 0

    function startFileSearch(term) {
        const words = term.split(/\s+/).filter(w => w !== "");
        if (words.length === 0)
            return;
        const command = ["fd", "--ignore-case", "--absolute-path", "--max-results", "80", "--exclude", ".git", "--exclude", "node_modules", "--exclude", "__pycache__", "--exclude", "result"];
        for (const w of words.slice(1))
            command.push("--and", turkishPattern(w));
        command.push("--", turkishPattern(words[0]), home);
        const id = ++fileSearchId;
        searchingFiles = true;
        Commands.run(command, (code, out) => {
            if (id !== root.fileSearchId)
                return;
            root.files = out.split("\n").filter(line => line !== "");
            root.filesFor = term;
            root.searchingFiles = false;
        });
    }

    function fileResultsFor(term) {
        if (term.length < 2) {
            return [
                {
                    id: "hint",
                    kind: "hint",
                    title: "Dosya ara",
                    subtitle: "Ev klasöründe aranır; en az iki harf yaz",
                    icon: "search",
                    enabled: false
                }
            ];
        }
        if (filesFor !== term && files.length === 0) {
            return [
                {
                    id: "hint",
                    kind: "hint",
                    title: "Aranıyor…",
                    subtitle: "",
                    icon: "search",
                    enabled: false
                }
            ];
        }
        const q = fold(term);
        const items = files.map(path => {
            const isDir = path.endsWith("/");
            const clean = isDir ? path.slice(0, -1) : path;
            const name = clean.slice(clean.lastIndexOf("/") + 1);
            const folder = clean.slice(0, clean.lastIndexOf("/")).replace(root.home, "~");
            return {
                id: "file:" + clean,
                kind: "file",
                title: name,
                subtitle: folder,
                hint: "Ctrl+Enter: klasöründe göster",
                image: Quickshell.iconPath(FileKinds.iconFor(name, isDir), true),
                tag: isDir ? "Klasör" : "Dosya",
                // Ad aramaya ne kadar benziyor; sonra yol ne kadar kısa
                score: itemScore(q, [fold(name)]) * 10 - clean.split("/").length,
                run: () => Commands.open(["xdg-open", clean]),
                runAlt: () => Commands.open(["dolphin", "--select", clean])
            };
        });
        items.sort((a, b) => b.score - a.score);
        if (items.length === 0) {
            return [
                {
                    id: "hint",
                    kind: "hint",
                    title: "Dosya bulunamadı",
                    subtitle: "Gizli klasörler ve .gitignore'dakiler aranmaz",
                    icon: "search",
                    enabled: false
                }
            ];
        }
        return items.slice(0, maxResults);
    }

    FileView {
        path: root.home + "/.local/state/desk/search.json"
        printErrors: false
        onAdapterUpdated: writeAdapter()
        onLoadFailed: error => {
            if (error === FileViewError.FileNotFound)
                writeAdapter();
        }

        JsonAdapter {
            id: store
            // { "app:zen-beta": { count: 12, last: 1763460000000 }, … }
            property var usage: ({})
        }
    }
}
