pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland

// Pencere değiştirici (Alt+Tab), macOS'taki gibi: Alt basılıyken Tab ile pencereler arasında gezilir,
// Alt bırakılınca seçilen pencereye geçilir. Shift+Alt+Tab geri gider, Esc vazgeçer.
// Pencereler son kullanılandan eskiye (odaklandıkça öne geçer); başka alandakiler de listede.
//
// Hyprland tarafı (keybinds.lua): Alt+Tab "switcher next"i çağırır ve "switcher" tuş takımına girer;
// orada Tab, Shift+Tab, Alt'ı bırakmak ve Esc buraya gelir. Ayrıca açıkken klavye desk'te olduğu için
// Alt'ın bırakılması pencereden de yakalanır (modules/switcher/WindowSwitcher.qml). İkisi birden gelse de
// geçiş bir kez yapılır.
Singleton {
    id: root

    property bool active: false        // değiştirici açık (görünmesi kısa bir an sonra)
    property bool shown: false         // ekranda görünüyor
    property var items: []             // açılıştaki pencereler (sırası açıkken değişmez)
    property int index: 0              // seçili pencere
    property string screenName: ""     // hangi ekranda açıldı

    // ---------- Son kullanılan sırası ----------
    // Pencere adresleri, en son odaklanan başta. Hyprland'in odak geçmişiyle başlar, sonra
    // odak değiştikçe güncellenir (Hyprland bu sırayı ayrıca göndermiyor).
    property var recent: []

    Connections {
        target: Hyprland
        function onActiveToplevelChanged() {
            root.touch(Hyprland.activeToplevel);
        }
    }

    function touch(toplevel) {
        const address = toplevel?.address ?? "";
        if (address === "")
            return;
        recent = [address].concat(recent.filter(a => a !== address)).slice(0, 200);
    }

    // Değiştiricide görünen pencereler: son kullanılan başta; listede olmayanlar Hyprland'in
    // odak geçmişine göre arkada
    function windows() {
        const order = address => {
            const i = recent.indexOf(address);
            return i >= 0 ? i : 1000;
        };
        return Hyprland.toplevels.values.filter(t => (t.address ?? "") !== "" && WindowManager.appIdOf(t) !== "").sort((a, b) => order(a.address) - order(b.address) || (a.lastIpcObject?.focusHistoryID ?? 99) - (b.lastIpcObject?.focusHistoryID ?? 99));
    }

    // ---------- Açma, gezinme ----------
    // Hızlı bir Alt+Tab (Alt hemen bırakıldı) için bırakma isteği açılmadan önce gelebilir:
    // o zaman pencere göstermeden doğrudan bir öncekine geçilir.
    property real commitRequestedAt: 0

    function next() {
        step(1);
    }
    function previous() {
        step(-1);
    }

    function step(direction) {
        if (!active) {
            const list = windows();
            if (list.length === 0) {
                resetKeys();
                return;
            }
            const start = list.length > 1 ? (direction > 0 ? 1 : list.length - 1) : 0;
            if (Date.now() - commitRequestedAt < 400) {
                commitRequestedAt = 0;
                WindowManager.focus(list[start]);
                resetKeys();
                return;
            }
            items = list;
            index = start;
            screenName = Hyprland.focusedMonitor?.name ?? "";
            active = true;
            showTimer.restart();
            return;
        }
        if (items.length > 0)
            index = (index + direction + items.length) % items.length;
        // Tab'a art arda basılıyorsa hemen görünsün
        shown = true;
    }

    // Kısa bir Alt+Tab'da değiştirici hiç görünmeden geçilir (titreme olmasın)
    Timer {
        id: showTimer
        interval: 110
        onTriggered: {
            if (root.active)
                root.shown = true;
        }
    }

    function select(i) {
        if (active && i >= 0 && i < items.length)
            index = i;
    }

    // Alt bırakıldı ya da bir pencereye tıklandı
    function commit() {
        if (!active) {
            commitRequestedAt = Date.now();
            return;
        }
        const target = items[index] ?? null;
        close();
        if (target)
            WindowManager.focus(target);
    }

    function cancel() {
        if (active)
            close();
    }

    function close() {
        showTimer.stop();
        active = false;
        shown = false;
        items = [];
        resetKeys();
    }

    // Hyprland'in "switcher" tuş takımından çık (Alt bırakılmadan fareyle seçildiyse diye)
    function resetKeys() {
        WindowManager.dispatch('hl.dsp.submap("reset")');
    }

    // Açıkken pencere kapanırsa listeden düşer
    Connections {
        target: Hyprland.toplevels
        function onValuesChanged() {
            if (!root.active)
                return;
            const alive = Hyprland.toplevels.values;
            const selected = root.items[root.index] ?? null;
            const list = root.items.filter(t => alive.includes(t));
            if (list.length === 0) {
                root.close();
                return;
            }
            root.items = list;
            root.index = Math.max(0, list.indexOf(selected));
        }
    }

    Component.onCompleted: {
        // Başlangıçta Hyprland'in odak geçmişi
        recent = Hyprland.toplevels.values.slice().sort((a, b) => (a.lastIpcObject?.focusHistoryID ?? 99) - (b.lastIpcObject?.focusHistoryID ?? 99)).map(t => t.address ?? "").filter(a => a !== "");
    }
}
