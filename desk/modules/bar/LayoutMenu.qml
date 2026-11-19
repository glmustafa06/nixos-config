import QtQuick
import qs.services
import qs.modules.menu

// "Düzen" menüsü: etkin alanın düzeni ve scrolling'de sütun genişliği.
// Kısayollar layouts.lua'dakilerle aynı.
MenuPopup {
    id: root

    readonly property string current: WindowManager.layout

    function layoutEntry(name, shortcut) {
        return {
            text: name,
            layoutIcon: name,
            shortcut: shortcut,
            checked: current === name,
            action: () => WindowManager.setLayout(name)
        };
    }

    // Sütun genişlikleri layouts.lua'daki explicit_column_widths ile aynı
    function widthEntry(label, value) {
        return {
            text: label,
            shortcut: "%" + Math.round(Number(value) * 100),
            enabled: WindowManager.hasWindow,
            action: () => WindowManager.layoutMessage("colresize " + value)
        };
    }

    entries: {
        const list = [
            layoutEntry("dwindle", "Super Alt D"),
            layoutEntry("scrolling", "Super Alt S"),
            layoutEntry("monocle", "Super Alt M"),
            {
                separator: true
            },
            {
                text: "Sonraki düzen",
                shortcut: "Super N",
                action: () => WindowManager.cycleLayout()
            }
        ];
        if (current === "scrolling") {
            list.push({
                separator: true
            }, {
                header: true,
                text: "Sütun genişliği",
                shortcut: "Super R"
            }, widthEntry("Yarım", "0.5"), widthEntry("Geniş", "0.8"), widthEntry("Tam", "1.0"));
        }
        return list;
    }
}
