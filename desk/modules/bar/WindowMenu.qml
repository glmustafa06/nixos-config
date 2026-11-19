import QtQuick
import Quickshell.Hyprland
import qs.services
import qs.modules.menu

// "Pencere" menüsü: etkin pencereye uygulanan komutlar.
// Menü açıldığı andaki pencere hedef alınır; eylemler pencereyi adresiyle seçer.
MenuPopup {
    id: root

    property var target: null

    onOpenChanged: {
        if (open) {
            target = WindowManager.window;
            Hyprland.refreshToplevels(); // onay işaretleri güncel olsun
        }
    }

    readonly property bool floating: WindowManager.isFloating(target)
    readonly property bool fullscreen: WindowManager.isFullscreen(target)
    readonly property bool scrolling: WindowManager.layout === "scrolling"

    // Alanlar: 1–5 her zaman, açık olan büyük numaralılar da
    readonly property var workspaceIds: {
        const list = [1, 2, 3, 4, 5];
        for (const ws of Hyprland.workspaces.values) {
            if (ws.id > 5 && !list.includes(ws.id))
                list.push(ws.id);
        }
        return list.sort((a, b) => a - b);
    }
    readonly property int currentWorkspace: target?.workspace?.id ?? -1

    entries: target === null ? [] : [
        {
            text: "Yüzdür",
            icon: "picture-in-picture-2",
            shortcut: "Super ⇧ F",
            checked: floating,
            action: () => WindowManager.toggleFloating(target)
        },
        {
            text: "Tam ekran",
            icon: "maximize",
            shortcut: "Super F",
            checked: fullscreen,
            action: () => WindowManager.toggleFullscreen(target)
        },
        {
            text: "Büyüt",
            icon: "square",
            shortcut: "Super M",
            checked: WindowManager.isMaximized(target),
            action: () => WindowManager.toggleMaximized(target)
        },
        {
            separator: true
        },
        {
            text: "Başka alana taşı",
            icon: "arrow-right-left",
            submenu: workspaceIds.map(id => ({
                        text: id + ". alan",
                        shortcut: id <= 9 ? "Super ⇧ " + id : "",
                        checked: id === currentWorkspace,
                        enabled: id !== currentWorkspace,
                        action: () => WindowManager.moveToWorkspace(target, id)
                    })).concat([
                    {
                        separator: true
                    },
                    {
                        text: "Boş bir alana",
                        action: () => WindowManager.moveToWorkspace(target, "empty")
                    }
                ])
        },
        {
            // Hyprland yalnızca yüzen pencereyi sabitleyebiliyor; menü gerekirse önce yüzdürür
            text: "Bütün alanlarda göster",
            icon: "pin",
            checked: WindowManager.isPinned(target),
            enabled: !fullscreen,
            action: () => WindowManager.togglePinned(target)
        },
        {
            // scrolling düzeninde odaktaki sütunu ekranın ortasına getirir
            text: "Sütunu ortala",
            icon: "columns-3",
            shortcut: "Super C",
            enabled: scrolling && !floating,
            action: () => WindowManager.layoutMessage("center")
        },
        {
            separator: true
        },
        {
            text: "Kapat",
            icon: "x",
            shortcut: "Alt F4",
            action: () => WindowManager.close(target)
        }
    ]
}
