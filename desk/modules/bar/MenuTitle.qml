import QtQuick

// Menü açan bar öğesi (uygulama adı, Pencere, Düzen).
// Basınca açılır ya da kapanır. Bir menü açıkken üstüne gelince o menüye geçilir (macOS gibi).
BarItem {
    id: root

    required property var bar
    required property string menuKey

    active: bar.openMenu === menuKey

    onPressed: bar.toggleMenu(menuKey)
    onHoveredChanged: {
        if (hovered)
            bar.hoverMenu(menuKey);
    }
}
