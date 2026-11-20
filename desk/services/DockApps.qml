pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import qs.settings

// Dock'taki uygulamalar: sabitlenenler (dosyada saklanır) ve penceresi açık olanlar.
//
// Her uygulama bir "anahtar"la tanınır: .desktop kaydının kimliği ("org.kde.dolphin" gibi).
// Kaydı bulunamayan pencerelerin anahtarı "app:<pencere sınıfı>".
// Sabitlenenler Ayarlar dosyasında (Settings → dock.pinned); dock'tan sağ tıkla ya da sürükleyerek
// değişir. Ayarlar'a hiç yazılmamışsa eski ~/.local/state/desk/dock.json okunur (ilk değişiklikte taşınır).
Singleton {
    id: root

    // --- Sabitlenenler
    // Dosyada kayıt kimlikleri ya da aranacak kısa adlar durur ("zen" → Zen Browser'ın kaydı).
    // Kaydı bulunamayanlar (kurulu olmayan uygulama) dock'ta görünmez.
    readonly property var pinnedKeys: {
        DesktopEntries.applications.values; // uygulama listesi dolunca yeniden hesaplansın
        const list = [];
        for (const name of pinnedNames) {
            const entry = lookup(name);
            if (entry && !list.includes(entry.id))
                list.push(entry.id);
        }
        return list;
    }

    // --- Açık pencereler, uygulamaya göre: { anahtar: [pencere, …] } (açılış sırasıyla)
    readonly property var windowsByKey: {
        DesktopEntries.applications.values;
        const map = {};
        for (const toplevel of Hyprland.toplevels.values) {
            const key = keyOf(toplevel);
            if (key === "")
                continue;
            if (!map[key])
                map[key] = [];
            map[key].push(toplevel);
        }
        return map;
    }

    // Sabitlenmemiş ama açık olanlar (ilk açılış sırasıyla)
    readonly property var runningKeys: Object.keys(windowsByKey).filter(key => !pinnedKeys.includes(key))

    function lookup(name) {
        return DesktopEntries.byId(name) ?? DesktopEntries.heuristicLookup(name);
    }

    function keyOf(toplevel) {
        const appId = WindowManager.appIdOf(toplevel);
        if (appId === "")
            return "";
        const entry = DesktopEntries.heuristicLookup(appId);
        return entry ? entry.id : "app:" + appId;
    }

    function entryOf(key) {
        return key.startsWith("app:") ? null : lookup(key);
    }

    function windowsOf(key) {
        return windowsByKey[key] ?? [];
    }

    function isPinned(key) {
        return pinnedKeys.includes(key);
    }

    function nameOf(key) {
        const entry = entryOf(key);
        if (entry)
            return entry.name;
        const id = key.replace(/^app:/, "");
        return id.charAt(0).toUpperCase() + id.slice(1);
    }

    // Bazı uygulamaların .desktop'taki simge adı Colloid'de başka adla duruyor.
    // Eşleşme yoksa uygulamanın kendi simgesi görünür (Zen'in siyah yuvarlağı gibi).
    readonly property var iconAliases: ({
            "zen": "zen-browser",
            "zen-beta": "zen-browser",
            "zen-twilight": "zen-browser",
            "zen-browser-beta": "zen-browser"
        })

    // Simge dosyası: önce Colloid'deki karşılığı, sonra kendi adı, o da yoksa genel uygulama simgesi
    function iconOf(key) {
        const name = entryOf(key)?.icon || key.replace(/^app:/, "");
        const alias = iconAliases[name] ?? "";
        return (alias !== "" ? Quickshell.iconPath(alias, true) : "") || Quickshell.iconPath(name, true) || Quickshell.iconPath("application-x-executable", true);
    }

    // --- Eylemler
    // Tıklama: açık değilse başlatır (true döner). Açıksa en son kullanılan penceresine gider;
    // o pencere zaten odaktaysa sıradaki penceresine geçer.
    function activate(key) {
        const windows = windowsOf(key);
        if (windows.length === 0) {
            launch(key);
            return true;
        }
        const index = windows.indexOf(Hyprland.activeToplevel);
        const target = index >= 0 ? windows[(index + 1) % windows.length] : windows.reduce((best, w) => focusOrder(w) < focusOrder(best) ? w : best);
        WindowManager.focus(target);
        return false;
    }

    // Hyprland'in odak geçmişi: 0 = şu anki pencere, büyüdükçe daha eski
    function focusOrder(toplevel) {
        const order = toplevel.lastIpcObject?.focusHistoryID;
        return order === undefined || order < 0 ? 1e9 : order;
    }

    function launch(key) {
        Commands.launch(entryOf(key));
    }

    function closeAll(key) {
        windowsOf(key).forEach(w => WindowManager.close(w));
    }

    // Kayıttaki adlar: Ayarlar'daki liste, yoksa eski dosyadaki
    readonly property var pinnedNames: Settings.s.dock.pinned ?? store.pinned

    function savePinned(list) {
        Settings.set("dock.pinned", list);
    }

    function setPinned(key, on) {
        const list = pinnedNames.filter(name => (lookup(name)?.id ?? name) !== key);
        if (on)
            list.push(key);
        savePinned(list);
    }

    // Sürükleyerek sıralama: sabitlenenlerin yeni sırası (kayıt kimlikleri). Listede olmayan açık bir
    // uygulama varsa o da sabitlenir. Kurulu olmayan (bulunamayan) adlar silinmez, sonda kalır:
    // uygulama yeniden kurulunca dock'a geri gelir.
    function setPinnedOrder(keys) {
        const missing = pinnedNames.filter(name => !lookup(name));
        savePinned(keys.filter(key => !key.startsWith("app:")).concat(missing));
    }

    // Bildirimi gönderen uygulamanın dock anahtarı ("" bulunamazsa): önce bildirimin söylediği
    // .desktop kaydı, sonra uygulama adı (kimlik, pencere sınıfı ya da kayıttaki ad)
    function keyForApp(desktopEntry, appName) {
        const byEntry = desktopEntry ? lookup(desktopEntry) : null;
        if (byEntry)
            return byEntry.id;
        if (!appName)
            return "";
        const byName = lookup(appName);
        if (byName)
            return byName.id;
        const folded = appName.toLowerCase();
        return DesktopEntries.applications.values.find(e => e.name.toLowerCase() === folded)?.id ?? "";
    }

    // --- Dosya bırakma
    // Uygulama dosya açabiliyor mu: .desktop'taki Exec'te %f, %F, %u ya da %U olmalı
    function canOpenFiles(key) {
        const entry = entryOf(key);
        return entry !== null && /%[fFuU]/.test(entry.execString ?? "");
    }

    // Dosyaları (yol ya da adres) uygulamayla aç
    function openWith(key, paths) {
        const entry = entryOf(key);
        if (entry && paths.length > 0)
            Commands.launchWith(entry, paths);
    }

    // Eski dosya (yalnızca okunur): Ayarlar'a geçmeden önceki sabitlenenler
    FileView {
        path: Quickshell.env("HOME") + "/.local/state/desk/dock.json"
        printErrors: false

        JsonAdapter {
            id: store

            // İlk açılışta sabitlenenler (dosya da yoksa)
            property var pinned: ["zen", "org.kde.dolphin", "kitty", "code", "obsidian", "spotify"]
        }
    }
}
