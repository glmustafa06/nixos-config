import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import qs.theme
import qs.components
import qs.services

// Kısayollar: Hyprland'deki açıklamalı kısayollar (hyprctl binds -j; açıklamalar
// hypr/config/keybinds.lua ve layouts.lua'da, "Grup: ne yapar" biçiminde). Yalnızca gösterir;
// değiştirmek için keybinds.lua.
SettingsPage {
    id: page

    title: "Kısayollar"
    subtitle: "Değiştirmek için: nixos-config/hypr/config/keybinds.lua"

    property var groups: []
    property string query: ""
    property bool failed: false

    readonly property var shownGroups: {
        const q = query.trim().toLocaleLowerCase("tr");
        if (q === "")
            return groups;
        return groups.map(group => ({
                    name: group.name,
                    rows: group.rows.filter(row => (group.name + " " + row.text + " " + row.combos.map(c => c.join(" ")).join(" ")).toLocaleLowerCase("tr").includes(q))
                })).filter(group => group.rows.length > 0);
    }

    // ---------- Tuş adları ----------
    readonly property var keyNames: ({
            "return": "Enter",
            "space": "Boşluk",
            "escape": "Esc",
            "tab": "Tab",
            "comma": ",",
            "period": ".",
            "print": "Print",
            "left": "←",
            "right": "→",
            "up": "↑",
            "down": "↓",
            "delete": "Delete",
            "backspace": "Backspace",
            "mouse:272": "Sol tık",
            "mouse:273": "Sağ tık",
            "mouse:274": "Orta tık"
        })

    function modifiers(mask) {
        const list = [];
        if (mask & 64)
            list.push("Super");
        if (mask & 4)
            list.push("Ctrl");
        if (mask & 8)
            list.push("Alt");
        if (mask & 1)
            list.push("Shift");
        return list;
    }

    function keyName(key) {
        const lower = String(key).toLowerCase();
        if (keyNames[lower] !== undefined)
            return keyNames[lower];
        return lower.length === 1 ? lower.toLocaleUpperCase("tr") : key.charAt(0).toUpperCase() + key.slice(1);
    }

    // hyprctl binds -j → gruplar; aynı açıklamalılar tek satır (Super+← ya da Super+H),
    // 1…9 gibi rakam dizileri tek tuşta ("1–9")
    function build(binds) {
        const groups = [];
        for (const bind of binds) {
            if (!bind.has_description || (bind.submap ?? "") !== "")
                continue;
            const text = String(bind.description);
            const colon = text.indexOf(": ");
            const groupName = colon > 0 ? text.slice(0, colon) : "Diğer";
            const rowText = colon > 0 ? text.slice(colon + 2) : text;
            let group = groups.find(g => g.name === groupName);
            if (!group) {
                group = {
                    name: groupName,
                    rows: []
                };
                groups.push(group);
            }
            let row = group.rows.find(r => r.text === rowText);
            if (!row) {
                row = {
                    text: rowText,
                    raw: []
                };
                group.rows.push(row);
            }
            row.raw.push({
                mods: bind.modmask ?? 0,
                key: String(bind.key ?? "")
            });
        }
        for (const group of groups) {
            for (const row of group.rows) {
                row.combos = [];
                const digits = row.raw.filter(r => /^[0-9]$/.test(r.key));
                const sameMods = digits.length > 2 && digits.every(r => r.mods === digits[0].mods);
                if (sameMods) {
                    const keys = digits.map(r => Number(r.key)).sort((a, b) => a - b);
                    row.combos.push(modifiers(digits[0].mods).concat([`${keys[0]}–${keys[keys.length - 1]}`]));
                }
                for (const r of row.raw) {
                    if (sameMods && digits.includes(r))
                        continue;
                    row.combos.push(modifiers(r.mods).concat([keyName(r.key)]));
                }
                delete row.raw;
            }
        }
        return groups;
    }

    Process {
        running: true
        command: ["hyprctl", "binds", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    page.groups = page.build(JSON.parse(text));
                    page.failed = false;
                } catch (e) {
                    page.failed = true;
                }
            }
        }
        onExited: code => {
            if (code !== 0)
                page.failed = true;
        }
    }

    SearchField {
        Layout.fillWidth: true
        placeholder: "Kısayol ara"
        onTextChanged: page.query = text
    }

    Text {
        visible: page.failed || (page.groups.length > 0 && page.shownGroups.length === 0)
        text: page.failed ? "Kısayollar okunamadı (hyprctl binds)" : "Sonuç yok"
        color: Colors.textMuted
        font.family: Typography.family
        font.pixelSize: Typography.body
    }

    Repeater {
        model: page.shownGroups

        SettingsSection {
            required property var modelData

            title: modelData.name

            Repeater {
                model: modelData.rows

                OptionRow {
                    required property var modelData

                    title: modelData.text

                    Row {
                        spacing: 6

                        Repeater {
                            model: modelData.combos

                            Row {
                                required property var modelData
                                required property int index

                                spacing: 6

                                Text {
                                    visible: parent.index > 0
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "ya da"
                                    color: Colors.textFaint
                                    font.family: Typography.family
                                    font.pixelSize: Typography.small
                                }
                                KeyCaps {
                                    keys: parent.modelData
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
