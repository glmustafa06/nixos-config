pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Takvim etkinlikleri: yalnızca bu bilgisayarda, ~/.local/state/desk/calendar.json dosyasında.
// Bildirim merkezindeki takvimden eklenir, değiştirilir, silinir (modules/notifications/Agenda.qml).
//
// Her etkinlik düz bir JS nesnesi:
//   { id, title, date: "2026-11-24", time: "12:00" ya da "" (tüm gün),
//     repeat: "none" | "weekly" | "monthly" | "yearly",
//     reminder: -1 (yok) ya da kaç dakika önce (0: vaktinde). Tüm gün etkinliğinde 0 = o gün 09:00,
//               1440 = bir gün önce 09:00.
//     skip: ["2026-12-01"] }  tekrarlanan etkinliğin silinen tek günleri
//
// Hatırlatma vakti gelince bildirim gelir (Notifications.notify; tıklayınca takvim o günde açılır).
// desk kapalıyken kaçan hatırlatma, etkinlik henüz bitmediyse açılınca gelir. Gönderilenler aynı
// dosyada (notified) tutulur: yeniden açılınca ikinci kez gelmez.
Singleton {
    id: root

    readonly property var events: store.events ?? []
    property bool loaded: false

    // Tüm gün etkinliklerinin hatırlatma saati
    readonly property int allDayReminderHour: 9

    readonly property var repeatNames: ({
            "none": "Tekrar yok",
            "weekly": "Her hafta",
            "monthly": "Her ay",
            "yearly": "Her yıl"
        })

    // ---------- Günler ----------
    function pad(n) {
        return String(n).padStart(2, "0");
    }
    function dayKey(date) {
        return `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())}`;
    }
    function parseDay(key) {
        const [y, m, d] = String(key).split("-").map(Number);
        return new Date(y, m - 1, d);
    }
    function dayStart(date) {
        return new Date(date.getFullYear(), date.getMonth(), date.getDate());
    }
    function addDays(date, n) {
        return new Date(date.getFullYear(), date.getMonth(), date.getDate() + n);
    }
    function sameDay(a, b) {
        return a.getFullYear() === b.getFullYear() && a.getMonth() === b.getMonth() && a.getDate() === b.getDate();
    }

    // Etkinlik o gün var mı (tekrarlarıyla)
    function occursOn(event, date) {
        const day = dayStart(date);
        const base = parseDay(event.date);
        if (day < base || (event.skip ?? []).includes(dayKey(day)))
            return false;
        switch (event.repeat) {
        case "weekly":
            return Math.round((day - base) / 86400000) % 7 === 0;
        case "monthly":
            return day.getDate() === base.getDate();
        case "yearly":
            return day.getDate() === base.getDate() && day.getMonth() === base.getMonth();
        default:
            return sameDay(day, base);
        }
    }

    // O günün etkinlikleri: önce tüm gün olanlar, sonra saat sırasıyla
    function eventsOn(date) {
        return events.filter(e => occursOn(e, date)).sort((a, b) => (a.time || "") < (b.time || "") ? -1 : (a.time || "") > (b.time || "") ? 1 : a.title.localeCompare(b.title));
    }

    // Ayın etkinliği olan günleri: { 24: true, … } (takvimdeki noktalar)
    function markedDays(year, month) {
        const marked = {};
        const days = new Date(year, month + 1, 0).getDate();
        for (let d = 1; d <= days; d++) {
            const date = new Date(year, month, d);
            if (events.some(e => occursOn(e, date)))
                marked[d] = true;
        }
        return marked;
    }

    // ---------- Yazılanı anlama ----------
    // Saat: "9", "930", "9:30", "09.30", "21 00" → "09:30" gibi; boş → "" (tüm gün); anlaşılmazsa null
    function parseTime(text) {
        const t = String(text ?? "").trim();
        if (t === "")
            return "";
        let m = t.match(/^(\d{1,2})(?:[:. ](\d{2}))?$/) ?? t.match(/^(\d{1,2})(\d{2})$/);
        if (!m)
            return null;
        const h = Number(m[1]), min = Number(m[2] ?? 0);
        if (h > 23 || min > 59)
            return null;
        return `${pad(h)}:${pad(min)}`;
    }

    // Tarih: "24.11.2026", "24.11", "24/11/26" → "2026-11-24"; anlaşılmazsa null
    function parseDate(text, fallbackYear) {
        const m = String(text ?? "").trim().match(/^(\d{1,2})[./-](\d{1,2})(?:[./-](\d{2}|\d{4}))?$/);
        if (!m)
            return null;
        let y = m[3] ? Number(m[3]) : fallbackYear;
        if (y < 100)
            y += 2000;
        const date = new Date(y, Number(m[2]) - 1, Number(m[1]));
        if (date.getDate() !== Number(m[1]) || date.getMonth() !== Number(m[2]) - 1)
            return null; // 31.02 gibi
        return dayKey(date);
    }

    function formatDate(key) {
        const d = parseDay(key);
        return `${pad(d.getDate())}.${pad(d.getMonth() + 1)}.${d.getFullYear()}`;
    }

    // "Bugün", "Yarın", "Dün" ya da "24 Kasım Salı"
    function dayTitle(date) {
        const today = dayStart(new Date());
        const diff = Math.round((dayStart(date) - today) / 86400000);
        if (diff === 0)
            return "Bugün";
        if (diff === 1)
            return "Yarın";
        if (diff === -1)
            return "Dün";
        const format = date.getFullYear() === today.getFullYear() ? "d MMMM dddd" : "d MMMM yyyy dddd";
        return date.toLocaleDateString(Qt.locale("tr_TR"), format);
    }

    function reminderText(event) {
        const r = event.reminder ?? -1;
        if (r < 0)
            return "";
        if (!event.time)
            return r >= 1440 ? "1 gün önce 09:00" : "O gün 09:00";
        if (r === 0)
            return "Vaktinde";
        return r >= 1440 ? "1 gün önce" : r >= 60 ? `${r / 60} sa önce` : `${r} dk önce`;
    }

    // ---------- Değiştirme ----------
    function save(list) {
        store.events = list;
    }

    // Yeni etkinlik; kimliğini döndürür
    function add(fields) {
        const event = Object.assign({
            id: Date.now().toString(36) + Math.random().toString(36).slice(2, 6),
            repeat: "none",
            reminder: -1,
            skip: []
        }, fields);
        save(events.concat([event]));
        skipPastReminders(event);
        return event.id;
    }

    function update(id, fields) {
        let changed = null;
        save(events.map(e => {
            if (e.id !== id)
                return e;
            changed = Object.assign({}, e, fields);
            return changed;
        }));
        if (changed) {
            // Saati ya da hatırlatması değişen etkinliğin hatırlatması yeniden hesaplanır
            forgetReminders(id);
            skipPastReminders(changed);
        }
    }

    function remove(id) {
        save(events.filter(e => e.id !== id));
        forgetReminders(id);
    }

    // Tekrarlanan etkinliğin yalnızca o günü silinir
    function skipDay(id, date) {
        const key = dayKey(date);
        save(events.map(e => e.id === id ? Object.assign({}, e, {
                skip: (e.skip ?? []).concat([key])
            }) : e));
    }

    // ---------- Hatırlatmalar ----------
    function startOf(event, day) {
        if (!event.time)
            return new Date(day.getFullYear(), day.getMonth(), day.getDate(), allDayReminderHour);
        const [h, m] = event.time.split(":").map(Number);
        return new Date(day.getFullYear(), day.getMonth(), day.getDate(), h, m);
    }

    function reminderAt(event, day) {
        return startOf(event, day).getTime() - (event.reminder ?? 0) * 60000;
    }

    // Hatırlatma hangi ana kadar gönderilebilir: zamanlı etkinlikte başladıktan 1 saat sonrasına,
    // tüm gün etkinliğinde o günün sonuna kadar
    function reminderDeadline(event, day) {
        return event.time ? startOf(event, day).getTime() + 3600000 : addDays(day, 1).getTime();
    }

    // Hatırlatması dün ile 2 gün sonrası arasına düşebilecek günler (1 gün önceki hatırlatmalar dahil)
    function candidateDays() {
        const today = dayStart(new Date());
        return [-1, 0, 1, 2].map(n => addDays(today, n));
    }

    // Eklenen ya da değişen etkinliğin vakti zaten geçmiş hatırlatması gönderilmez
    // (geçmişe etkinlik yazınca hemen bildirim gelmesin)
    function skipPastReminders(event) {
        if ((event.reminder ?? -1) < 0)
            return;
        const now = Date.now();
        const sent = Object.assign({}, store.notified ?? {});
        for (const day of candidateDays()) {
            if (occursOn(event, day) && reminderAt(event, day) < now)
                sent[event.id + "@" + dayKey(day)] = now;
        }
        store.notified = sent;
    }

    function forgetReminders(id) {
        const sent = Object.assign({}, store.notified ?? {});
        for (const key of Object.keys(sent)) {
            if (key.startsWith(id + "@"))
                delete sent[key];
        }
        store.notified = sent;
    }

    function checkReminders() {
        if (!loaded)
            return;
        const now = Date.now();
        const sent = Object.assign({}, store.notified ?? {});
        let changed = false;
        for (const day of candidateDays()) {
            for (const event of events) {
                if ((event.reminder ?? -1) < 0 || !occursOn(event, day))
                    continue;
                const key = event.id + "@" + dayKey(day);
                if (sent[key] || now < reminderAt(event, day) || now >= reminderDeadline(event, day))
                    continue;
                sent[key] = now;
                changed = true;
                remind(event, day);
            }
        }
        // Eski kayıtlar düşer
        for (const key of Object.keys(sent)) {
            if (now - sent[key] > 4 * 86400000) {
                delete sent[key];
                changed = true;
            }
        }
        if (changed)
            store.notified = sent;
    }

    function remind(event, day) {
        // "14:00 · 10 dk sonra" (bugün), "Yarın 14:00", "Bugün · tüm gün"
        let body;
        if (!event.time) {
            body = `${dayTitle(day)} · tüm gün`;
        } else if (!sameDay(day, new Date())) {
            body = `${dayTitle(day)} ${event.time}`;
        } else {
            const minutes = Math.round((startOf(event, day).getTime() - Date.now()) / 60000);
            const hours = Math.floor(minutes / 60);
            const left = hours > 0 ? `${hours} sa ${minutes % 60 ? (minutes % 60) + " dk " : ""}sonra` : `${minutes} dk sonra`;
            body = `${event.time} · ` + (minutes > 0 ? left : minutes > -2 ? "şimdi" : "başladı");
        }
        const key = dayKey(day);
        Notifications.notify("Takvim", event.title, body, "calendar", 1, () => Ui.calendarRequested(key), "calendar");
    }

    Timer {
        running: root.loaded
        interval: 15000
        repeat: true
        triggeredOnStart: true
        onTriggered: root.checkReminders()
    }

    // ---------- Saklama ----------
    FileView {
        path: Quickshell.env("HOME") + "/.local/state/desk/calendar.json"
        printErrors: false
        onAdapterUpdated: writeAdapter()
        onLoaded: root.loaded = true
        onLoadFailed: error => {
            root.loaded = true;
            if (error === FileViewError.FileNotFound)
                writeAdapter();
        }

        JsonAdapter {
            id: store

            property var events: []
            // "kimlik@gün" → gönderildiği an (ms)
            property var notified: ({})
        }
    }
}
