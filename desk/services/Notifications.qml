pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications
import Quickshell.Services.UPower

// Bildirimler: kendi bildirim sunucumuz (org.freedesktop.Notifications).
// Sistemde tek bildirim sunucusu olabilir: dunst, mako gibi başka biri çalışmamalı (plan: Sorun 63).
//
//   history  merkezdeki bildirimler, en yenisi başta (en çok 50; dosyada saklanır)
//   current  şu an adada gösterilen bildirim; queue sıradakiler
//
// Her kayıt düz bir JS nesnesi:
//   { key, appName, desktopEntry, summary, body, icon (dosya adresi), glyph (çizgi simge adı),
//     urgency (0 düşük, 1 normal, 2 acil), time (ms), live (Notification ya da null), run }
// live: uygulamanın gönderdiği canlı bildirim; eylemler ve yanıt bunun üstünden yapılır.
// Shell yeniden açılınca live kalmaz (dosyadan gelenlerde null); eylemler o zaman yoktur.
Singleton {
    id: root

    readonly property int maxHistory: 50
    readonly property int popupTime: 5000
    // Adada sırada en çok bu kadar bildirim bekler; fazlası (en eskiler) yalnızca merkezde kalır.
    // Bir uygulama art arda 30 bildirim gönderirse ada 2,5 dakika meşgul olmasın.
    readonly property int maxQueue: 3

    property var history: []
    property var queue: []
    property var current: null
    // Fare adanın üstündeyken bildirim kapanmaz
    property bool hold: false

    // Uygulama adı → bu zamana kadar susturuldu (ms)
    property var mutedUntil: ({})

    // Göreli zamanlar ("5 dk") dakikada bir yenilensin diye
    property real now: Date.now()
    Timer {
        running: root.history.length > 0
        interval: 60000
        repeat: true
        onTriggered: root.now = Date.now()
    }

    property int nextKey: 1

    // ---------- Gruplar (merkez): uygulamaya göre, en yeni grup başta ----------
    readonly property var groups: {
        const map = {};
        const order = [];
        for (const entry of history) {
            const name = entry.appName || "Bildirim";
            if (!map[name]) {
                map[name] = {
                    appName: name,
                    entries: []
                };
                order.push(name);
            }
            map[name].entries.push(entry);
        }
        return order.map(name => map[name]);
    }

    // ---------- Sunucu ----------
    NotificationServer {
        id: server

        keepOnReload: true
        persistenceSupported: true
        bodySupported: true
        bodyMarkupSupported: true
        bodyHyperlinksSupported: false
        actionsSupported: true
        imageSupported: true
        inlineReplySupported: true

        onNotification: notification => root.receive(notification)
    }

    // Uygulama bir bildirimi güncellerse (aynı numarayla yenisini gönderirse) Quickshell yeni
    // bildirim açmaz, var olanın yazılarını değiştirir: kayıt yerinde güncellenir, ada yeniden açılmaz
    // (indirme yüzdesi gibi sık güncellenen bildirimler adayı meşgul etmesin).
    function receive(n) {
        n.tracked = true;

        // Shell yeniden yüklendi: aynı bildirim zaten geçmişte (dosyadan geldi); bağlanır, yeniden gösterilmez
        if (n.lastGeneration) {
            // Önceki açılıştan kalan geçici bildirim artık gösterilmeyecek: biter
            if (n.transient) {
                n.expire();
                return;
            }
            const old = history.find(e => !e.live && e.id === n.id && e.appName === n.appName && e.summary === n.summary);
            if (old) {
                old.live = n;
                watch(old);
                history = history.slice();
                return;
            }
        }

        const entry = {
            key: nextKey++,
            id: n.id,
            appName: n.appName,
            desktopEntry: n.desktopEntry,
            summary: n.summary,
            body: n.body,
            icon: iconFor(n),
            glyph: "",
            urgency: urgencyOf(n),
            time: Date.now(),
            transient: n.transient,
            live: n
        };
        watch(entry);

        if (!n.transient)
            add(entry);
        // Geçici bildirim adada gösterilemiyorsa (rahatsız etme, tam ekran) hemen biter
        if (!present(entry))
            dropTransient(entry);
    }

    // Uygulama bildirimi kendisi kapatırsa (okundu gibi) merkezden de kalkar.
    // Biz kaldırdıysak (removed) yapılacak bir şey yok.
    function watch(entry) {
        const live = entry.live;
        // Güncellenen yazılar saklanan kayda da geçsin
        const update = () => {
            if (entry.live !== live || entry.removed)
                return;
            entry.summary = live.summary;
            entry.body = live.body;
            root.history = root.history.slice();
        };
        live.summaryChanged.connect(update);
        live.bodyChanged.connect(update);
        live.closed.connect(reason => {
            entry.live = null;
            if (entry.removed)
                return;
            if (reason === NotificationCloseReason.CloseRequested || entry.transient)
                root.remove(entry, false);
            else
                root.history = root.history.slice(); // merkezde kalır; eylem düğmeleri kaybolsun
        });
    }

    function urgencyOf(n) {
        if (n.urgency === NotificationUrgency.Critical)
            return 2;
        if (n.urgency === NotificationUrgency.Low)
            return 0;
        return 1;
    }

    // Uygulamanın simgesi: dosya yolu, tema adı ya da .desktop kaydının simgesi
    function iconFor(n) {
        const icon = n.appIcon ?? "";
        // Dosya yolu (ekran görüntüsü gibi): boşluk ve "#" adresi bozmasın
        if (icon.startsWith("/"))
            return "file://" + icon.split("/").map(encodeURIComponent).join("/");
        if (icon.startsWith("file://") || icon.startsWith("image://"))
            return icon;
        if (icon !== "") {
            const path = Quickshell.iconPath(icon, true);
            if (path)
                return path;
        }
        if (n.desktopEntry)
            return DockApps.iconOf(n.desktopEntry);
        return "";
    }

    // ---------- Kendi bildirimlerimiz (pil uyarıları gibi) ----------
    // tag: "battery" gibi; aynı türden uyarıları bulmak için (saklanmaz)
    function notify(appName, summary, body, glyph, urgency, run, tag) {
        const entry = {
            key: nextKey++,
            id: 0,
            appName: appName,
            desktopEntry: "",
            summary: summary,
            body: body,
            icon: "",
            glyph: glyph,
            urgency: urgency,
            time: Date.now(),
            transient: false,
            live: null,
            run: run ?? null,
            tag: tag ?? ""
        };
        add(entry);
        present(entry);
    }

    // ---------- Geçmiş ----------
    function add(entry) {
        const list = [entry].concat(history);
        // En eskiler düşer; canlıysa uygulamaya da kapandı denir
        const dropped = list.slice(maxHistory);
        history = list.slice(0, maxHistory);
        for (const old of dropped)
            remove(old);
    }

    // dismissLive: uygulamaya "kullanıcı kapattı" denir (varsayılan)
    function remove(entry, dismissLive) {
        if (entry.removed)
            return;
        entry.removed = true;
        history = history.filter(e => e !== entry);
        queue = queue.filter(e => e !== entry);
        if (current === entry)
            next();
        if (dismissLive !== false && entry.live) {
            const live = entry.live;
            entry.live = null;
            live.dismiss();
        }
    }

    function removeGroup(appName) {
        for (const entry of history.filter(e => (e.appName || "Bildirim") === appName))
            remove(entry);
    }

    function clearAll() {
        for (const entry of history.slice())
            remove(entry);
    }

    // ---------- Adada gösterme ----------
    function suppressed(entry) {
        if (entry.urgency === 2)
            return false; // acil olanlar her zaman
        if (QuickSettings.doNotDisturb)
            return true;
        if ((mutedUntil[entry.appName] ?? 0) > Date.now())
            return true;
        // Tam ekran video ya da oyun sırasında gösterilmez
        return WindowManager.isFullscreen(WindowManager.window);
    }

    // Adaya çıkar ya da sıraya koy; gösterilmeyecekse false
    function present(entry) {
        if (entry.removed || entry.live?.lastGeneration || suppressed(entry))
            return false;
        if (current === null) {
            current = entry;
            restartPopupTimer();
        } else if (entry.urgency === 2 && current.urgency !== 2) {
            // Acil olan öne geçer
            queue = [current].concat(queue);
            current = entry;
            restartPopupTimer();
        } else {
            const waiting = queue.concat([entry]);
            // Acil olanlar hiç atlanmaz
            while (waiting.filter(e => e.urgency !== 2).length > maxQueue) {
                const oldest = waiting.findIndex(e => e.urgency !== 2);
                dropTransient(waiting[oldest]);
                waiting.splice(oldest, 1);
            }
            queue = waiting;
        }
        return true;
    }

    // Geçici bildirim yalnızca adada yaşar: adadan kalkınca ya da hiç çıkamayınca
    // uygulamaya "süresi doldu" denir. remove() içinden gelindiyse (removed) canlı bildirimle
    // remove'u çağıran ilgilenir (eylem çağrılacak olabilir).
    function dropTransient(entry) {
        if (!entry || entry.removed || !entry.transient || !entry.live)
            return;
        entry.removed = true;
        const live = entry.live;
        entry.live = null;
        live.expire();
    }

    // Adadaki bildirimi kapat (merkezde kalır). Geçici bildirimse tamamen biter.
    // Sırada bekleyip artık gösterilmeyecek olanlar (susturuldu, rahatsız etme açıldı) atlanır.
    function next() {
        const old = current;
        const skipped = queue.filter(e => suppressed(e));
        const rest = queue.filter(e => !suppressed(e));
        current = rest.length > 0 ? rest[0] : null;
        queue = rest.slice(1);
        restartPopupTimer();
        dropTransient(old);
        skipped.forEach(dropTransient);
    }

    // Acil bildirim kapatılana kadar kalır; fare üstündeyken beklenir
    function restartPopupTimer() {
        if (current && current.urgency !== 2 && !hold) {
            popupTimer.interval = current.urgency === 0 ? 3500 : popupTime;
            popupTimer.restart();
        } else {
            popupTimer.stop();
        }
    }

    Timer {
        id: popupTimer
        onTriggered: root.next()
    }
    // Fare adadan çıkınca süre baştan başlar
    onHoldChanged: restartPopupTimer()

    // ---------- Eylemler ----------
    // Kalıcı (resident) bildirim: eylemden sonra da yaşar (müzik çalarınki gibi); merkezde kalır,
    // yalnızca adadan kalkar. Ötekiler eylemden sonra biter: önce kayıt kaldırılır, çünkü
    // Quickshell eylemden hemen sonra bildirimi kendisi kapatır.
    function keepsAfterAction(entry) {
        return entry.live !== null && entry.live !== undefined && entry.live.resident;
    }
    function leaveIsland(entry) {
        if (current === entry)
            next();
        queue = queue.filter(e => e !== entry);
    }

    function actionList(live) {
        return live ? Array.from(live.actions ?? []) : [];
    }

    // Bildirime tıklandı: uygulamanın "default" eylemi, yoksa uygulamasının penceresi
    function activate(entry) {
        const live = entry.live;
        const action = actionList(live).find(a => a.identifier === "default") ?? null;
        if (action && keepsAfterAction(entry)) {
            leaveIsland(entry);
            action.invoke();
            return;
        }
        remove(entry, false);
        // Eylem çağrılınca Quickshell bildirimi kendisi kapatır; eylem yoksa biz kapatırız
        if (entry.run)
            entry.run();
        else if (action)
            action.invoke();
        else
            focusApp(entry);
        if (live && !action)
            live.dismiss();
    }

    function focusApp(entry) {
        const key = entry.desktopEntry ? (DockApps.lookup(entry.desktopEntry)?.id ?? "") : "";
        const target = key !== "" ? key : DockApps.lookup(entry.appName)?.id ?? "";
        if (target !== "" && DockApps.windowsOf(target).length > 0)
            DockApps.activate(target);
    }

    // Uygulamanın kendi düğmeleri ("Okundu" gibi); default ve yanıt hariç
    function actionsOf(entry) {
        if (!entry || !entry.live)
            return [];
        return actionList(entry.live).filter(a => a.identifier !== "default" && a.identifier !== "inline-reply");
    }

    function invoke(entry, action) {
        if (keepsAfterAction(entry))
            leaveIsland(entry);
        else
            remove(entry, false);
        action.invoke();
    }

    function canReply(entry) {
        return entry !== null && entry.live !== null && entry.live !== undefined && entry.live.hasInlineReply;
    }

    function reply(entry, text) {
        if (!canReply(entry) || text.trim() === "")
            return;
        const live = entry.live;
        if (keepsAfterAction(entry))
            leaveIsland(entry);
        else
            remove(entry, false);
        live.sendInlineReply(text);
    }

    // Uygulamayı 1 saat sustur (adada çıkmaz, merkezde birikir)
    function muteApp(appName) {
        const muted = Object.assign({}, mutedUntil);
        muted[appName] = Date.now() + 3600000;
        mutedUntil = muted;
        // next() sıradaki susturulmuşları da atlar
        if (current && current.appName === appName && current.urgency !== 2)
            next();
        else
            queue.filter(e => suppressed(e)).forEach(dropTransient);
        queue = queue.filter(e => !suppressed(e));
    }

    function isMuted(appName) {
        return (mutedUntil[appName] ?? 0) > now;
    }

    function unmuteApp(appName) {
        const muted = Object.assign({}, mutedUntil);
        delete muted[appName];
        mutedUntil = muted;
    }

    // Bildirim metni düz yazı olarak gösterilir: etiketler atılır, &amp; gibi kodlar çözülür.
    // (Biçimli metin <img> ile dışarıdan resim yükletebilirdi.)
    function plain(text) {
        const entities = {
            "&amp;": "&",
            "&lt;": "<",
            "&gt;": ">",
            "&quot;": "\"",
            "&apos;": "'",
            "&#39;": "'",
            "&nbsp;": " "
        };
        return String(text ?? "").replace(/<br\s*\/?>/gi, "\n").replace(/<[^>]*>/g, "").replace(/&(amp|lt|gt|quot|apos|#39|nbsp);/g, m => entities[m]).trim();
    }

    // "şimdi", "5 dk", "2 sa", "dün", "12 Kas"
    function timeText(time) {
        const minutes = Math.floor((now - time) / 60000);
        if (minutes < 1)
            return "şimdi";
        if (minutes < 60)
            return minutes + " dk";
        const hours = Math.floor(minutes / 60);
        if (hours < 24)
            return hours + " sa";
        if (hours < 48)
            return "dün";
        return new Date(time).toLocaleDateString(Qt.locale("tr_TR"), "d MMM");
    }

    // ---------- Pil uyarıları ----------
    // Her eşikte bir kez; şarja takılınca sıfırlanır
    property int batteryWarned: 100
    Connections {
        target: BatteryStatus
        function onLevelChanged() {
            root.checkBattery();
        }
        function onChargingChanged() {
            root.checkBattery();
        }
    }

    function checkBattery() {
        if (!BatteryStatus.present)
            return;
        if (BatteryStatus.charging) {
            batteryWarned = 100;
            // Şarja takılınca pil uyarısı adadan kalkar (merkezde kalır)
            queue = queue.filter(e => e.tag !== "battery");
            if (current && current.tag === "battery")
                next();
            return;
        }
        const percent = Math.round(BatteryStatus.level * 100);
        for (const threshold of [5, 10, 20]) {
            if (percent <= threshold && batteryWarned > threshold) {
                batteryWarned = threshold;
                if (threshold === 5)
                    notify("Pil", `Pil %${percent}`, "Bilgisayar birazdan kapanabilir; şarja tak.", "zap", 2, null, "battery");
                else
                    notify("Pil", `Pil %${percent}`, "Şarj etmeyi unutma. Tasarruf moduna geçmek için tıkla.", "zap", 1, () => PowerMode.set(PowerProfile.PowerSaver), "battery");
                return;
            }
        }
    }

    // ---------- Saklama ----------
    // Canlı nesne ve çalıştırılacak işlev saklanmaz; geçmiş açılışta yalnızca okunur.
    Timer {
        id: saveTimer
        interval: 1000
        onTriggered: store.items = root.history.map(e => ({
                    id: e.id,
                    appName: e.appName,
                    desktopEntry: e.desktopEntry,
                    summary: e.summary,
                    body: e.body,
                    icon: e.icon.startsWith("image://") ? "" : e.icon,
                    glyph: e.glyph,
                    urgency: e.urgency,
                    time: e.time
                }))
    }
    onHistoryChanged: {
        if (loaded)
            saveTimer.restart();
    }

    property bool loaded: false

    FileView {
        path: Quickshell.env("HOME") + "/.local/state/desk/notifications.json"
        printErrors: false
        onAdapterUpdated: writeAdapter()
        onLoaded: {
            // Dosyadakiler geçmişin sonuna eklenir. Shell yeniden yüklenirken canlı bildirim
            // dosyadan önce geldiyse (receive → lastGeneration) aynısı ikinci kez eklenmez.
            const same = (a, b) => a.id === b.id && a.appName === b.appName && a.summary === b.summary;
            const saved = (store.items ?? []).filter(e => !root.history.some(h => h.live && same(h, e))).map(e => Object.assign({}, e, {
                    key: root.nextKey++,
                    live: null,
                    transient: false,
                    icon: e.icon ?? "",
                    glyph: e.glyph ?? ""
                }));
            root.history = root.history.concat(saved).slice(0, root.maxHistory);
            root.loaded = true;
            root.checkBattery();
        }
        onLoadFailed: error => {
            root.loaded = true;
            root.checkBattery();
            if (error === FileViewError.FileNotFound)
                writeAdapter();
        }

        JsonAdapter {
            id: store
            property var items: []
        }
    }
}
