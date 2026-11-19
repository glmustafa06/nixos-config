import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import qs.theme
import qs.services
import qs.modules.menu

// Dock'un sağ tık menüsü (İndirilenler'de sol tık da). Hangi öğe için açıldığı: key.
//   Uygulama: pencereleri (birden çoksa), yeni pencere, uygulamanın eylemleri, Dock'ta tut, kapat
//   İndirilenler: son dosyalar ve klasörü açma
//   Çöp kutusu: aç, boşalt (menünün içinde onay sorarak)
//
// Bar menülerinin aksine ayrı bir pencere değil, dock penceresinin içinde çizilir.
// Ayrı pencerede satırlara tıklanamıyordu (18 Kasım, plan: Sorun 62): Hyprland'in odak
// yakalaması dock'tan açılan menü penceresini her zaman tanımadı. Aynı pencerede bu sorun olamaz.
// Satır görünümü bar menüleriyle aynı (MenuRow).
Rectangle {
    id: root

    property string key: ""
    property bool open: false

    signal closeRequested

    readonly property bool isApp: key !== "" && !key.startsWith("place:")
    readonly property var windows: isApp ? DockApps.windowsOf(key) : []
    readonly property var entry: isApp ? DockApps.entryOf(key) : null
    readonly property var actions: Array.from(entry?.actions ?? [])
    // Eylemlerde zaten "yeni pencere" varsa kendi satırımızı eklemeyiz (Zen, VS Code …)
    readonly property bool hasNewWindowAction: actions.some(a => /new.?window/i.test(a.id) || /new window|yeni pencere/i.test(a.name))

    // Menü açıldığı andaki etkin pencere (pencere listesindeki onay işareti için)
    property var focusedWindow: null
    // Çöp kutusu: "Boşalt…" seçilince menü onay sorusuna döner
    property bool confirmEmpty: false
    property int currentIndex: -1

    // Menü dock penceresine sığsın diye listeler sınırlı
    readonly property int maxWindows: 6

    onOpenChanged: {
        currentIndex = -1;
        confirmEmpty = false;
        if (!open)
            return;
        focusedWindow = Hyprland.activeToplevel;
        if (key === "place:downloads")
            Downloads.refresh();
        if (key === "place:trash")
            Trash.refresh();
    }
    onKeyChanged: {
        currentIndex = -1;
        confirmEmpty = false;
    }

    // Uzun pencere ve dosya adları menüyü genişletmesin
    function shorten(text) {
        return text.length > 42 ? text.slice(0, 40) + "…" : text;
    }

    // Satır seçildi: eylemi çalıştır, menüyü kapat ("keepOpen" satırları menüyü açık tutar)
    function trigger(index) {
        const e = rows[index];
        if (!e || e.separator || e.header || e.enabled === false)
            return;
        if (!e.keepOpen)
            root.closeRequested();
        if (e.action)
            e.action();
    }

    readonly property var appEntries: {
        const list = [];
        if (windows.length > 1) {
            list.push({
                header: true,
                text: "Pencereler"
            });
            for (const w of windows.slice(0, maxWindows)) {
                list.push({
                    text: shorten(w.title || DockApps.nameOf(key)),
                    checked: w === root.focusedWindow,
                    action: () => WindowManager.focus(w)
                });
            }
            if (windows.length > maxWindows) {
                list.push({
                    text: `… ve ${windows.length - maxWindows} pencere daha`,
                    enabled: false
                });
            }
            list.push({
                separator: true
            });
        }
        if (entry) {
            if (!hasNewWindowAction) {
                list.push({
                    text: "Yeni pencere",
                    icon: "plus",
                    action: () => Commands.launch(root.entry)
                });
            }
            for (const a of actions) {
                list.push({
                    text: a.name,
                    image: a.icon ? Quickshell.iconPath(a.icon, true) : "",
                    action: () => Commands.launch(root.entry, a)
                });
            }
            list.push({
                separator: true
            });
            list.push({
                text: "Dock'ta tut",
                icon: "pin",
                checked: DockApps.isPinned(key),
                action: () => DockApps.setPinned(root.key, !DockApps.isPinned(root.key))
            });
        }
        if (windows.length > 0) {
            list.push({
                text: windows.length > 1 ? "Hepsini kapat" : "Kapat",
                icon: "x",
                shortcut: windows.length > 1 ? windows.length + " pencere" : "",
                action: () => DockApps.closeAll(root.key)
            });
        }
        return list;
    }

    readonly property var downloadEntries: {
        const list = Downloads.files.map(file => ({
                    text: shorten(file.name),
                    image: Quickshell.iconPath(Downloads.iconFor(file), true),
                    action: () => Downloads.open(file.path)
                }));
        if (list.length === 0) {
            list.push({
                text: "Klasör boş",
                enabled: false
            });
        }
        list.push({
            separator: true
        });
        list.push({
            text: "İndirilenler klasörünü aç",
            image: Quickshell.iconPath("folder-download", true),
            action: () => Downloads.openFolder()
        });
        return list;
    }

    readonly property var trashEntries: confirmEmpty ? [
        {
            header: true,
            text: "Çöp kutusundakiler kalıcı olarak silinecek"
        },
        {
            text: "Boşalt",
            icon: "x",
            action: () => Trash.empty()
        },
        {
            text: "Vazgeç"
        }
    ] : [
        {
            text: "Çöp kutusunu aç",
            image: Quickshell.iconPath(Trash.full ? "user-trash-full" : "user-trash", true),
            action: () => Trash.open()
        },
        {
            separator: true
        },
        {
            text: "Boşalt…",
            enabled: Trash.full,
            keepOpen: true,
            action: () => root.confirmEmpty = true
        }
    ]

    readonly property var rows: key === "place:downloads" ? downloadEntries : key === "place:trash" ? trashEntries : appEntries
    readonly property bool hasChecks: rows.some(e => e.checked === true)
    readonly property bool hasIcons: rows.some(e => e.icon || e.image)

    visible: open
    implicitWidth: Math.max(Metrics.menuMinWidth, list.implicitWidth + Metrics.menuPadding * 2)
    implicitHeight: list.implicitHeight + Metrics.menuPadding * 2
    width: implicitWidth
    height: implicitHeight
    radius: Metrics.menuRadius
    color: Colors.menu
    border.width: 1
    border.color: Colors.panelBorder

    // Açılırken içerik hafifçe yukarı kayarak belirir (cam hemen gelir)
    onVisibleChanged: {
        if (visible)
            appear.restart();
    }
    ParallelAnimation {
        id: appear
        NumberAnimation {
            target: list
            property: "opacity"
            from: 0
            to: 1
            duration: Metrics.durationFast
            easing.type: Easing.OutCubic
        }
        NumberAnimation {
            target: shift
            property: "y"
            from: 6
            to: 0
            duration: Metrics.durationFast
            easing.type: Easing.OutCubic
        }
    }

    ColumnLayout {
        id: list

        anchors {
            fill: parent
            margins: Metrics.menuPadding
        }
        spacing: 0
        transform: Translate {
            id: shift
        }

        // Model satır sayısı: içerik değişince satırlar baştan kurulmaz, yerinde güncellenir
        Repeater {
            model: root.rows.length

            delegate: MenuRow {
                required property int index

                Layout.fillWidth: true
                entry: root.rows[index] ?? ({})
                showCheck: root.hasChecks
                showIcon: root.hasIcons
                highlighted: root.currentIndex === index

                onHovered: root.currentIndex = index
                onExited: {
                    if (root.currentIndex === index)
                        root.currentIndex = -1;
                }
                onClicked: root.trigger(index)
            }
        }
    }
}
