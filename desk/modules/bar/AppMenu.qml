import QtQuick
import Quickshell
import qs.services
import qs.modules.menu

// Uygulama adı menüsü.
// Pencere varken: uygulamanın .desktop dosyasındaki eylemler ("Yeni gizli pencere" gibi)
// ve bütün pencerelerini kapatma. Masaüstündeyken: duvar kâğıdı, ayarlar, kilit.
MenuPopup {
    id: root

    // Menü açıldığı andaki uygulama
    property string appId: ""
    property var desktopEntry: null

    onOpenChanged: {
        if (open) {
            appId = WindowManager.appId;
            desktopEntry = WindowManager.desktopEntry;
        }
    }

    readonly property var appWindows: appId === "" ? [] : WindowManager.windowsOf(appId)
    readonly property var actions: Array.from(desktopEntry?.actions ?? [])

    // Eylemlerde zaten "yeni pencere" varsa kendi satırımızı eklemeyiz (Zen, VS Code …)
    readonly property bool hasNewWindowAction: actions.some(a => /new.?window/i.test(a.id) || /new window|yeni pencere/i.test(a.name))

    function iconFor(name) {
        return name ? Quickshell.iconPath(name, true) : "";
    }

    readonly property var desktopItems: [
        {
            text: "Duvar kâğıdı",
            icon: "image",
            shortcut: "Super W",
            action: () => Ui.wallpaperRequested()
        },
        {
            text: "Kontrol merkezi",
            icon: "control-center",
            shortcut: "Super S",
            action: () => Ui.controlCenterRequested("main")
        },
        {
            separator: true
        },
        {
            text: "Kilitle",
            icon: "lock",
            shortcut: "Super Esc",
            action: () => Quickshell.execDetached(["loginctl", "lock-session"])
        },
        {
            text: "Oturum",
            icon: "log-out",
            shortcut: "Super ⇧ Esc",
            action: () => Ui.controlCenterRequested("session")
        }
    ]

    readonly property var appEntries: {
        const list = [];
        if (desktopEntry && !hasNewWindowAction) {
            list.push({
                text: "Yeni pencere",
                icon: "plus",
                action: () => Commands.launch(root.desktopEntry)
            });
        }
        for (const a of actions) {
            list.push({
                text: a.name,
                image: iconFor(a.icon),
                action: () => Commands.launch(root.desktopEntry, a)
            });
        }
        if (list.length > 0)
            list.push({
                separator: true
            });
        list.push({
            text: "Uygulamadan çık",
            icon: "log-out",
            shortcut: appWindows.length > 1 ? appWindows.length + " pencere" : "",
            action: () => root.appWindows.forEach(w => WindowManager.close(w))
        });
        return list;
    }

    entries: appId === "" ? desktopItems : appEntries
}
