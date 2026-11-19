import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell.Services.SystemTray
import Quickshell.Widgets
import qs.theme
import qs.modules.menu

// Sistem tepsisi: Steam, Discord gibi uygulamaların simgeleri.
// Sol tık uygulamayı açar (yalnızca menüsü olanlarda menüyü), sağ tık menüyü açar.
RowLayout {
    id: root

    // Menüler bardaki öteki menülerle aynı düzenle açılıp kapanır (Bar.qml)
    required property var bar

    spacing: Metrics.barItemSpacing

    Repeater {
        model: SystemTray.items

        delegate: BarItem {
            id: item

            required property var modelData
            readonly property string menuKey: "tray:" + modelData.id

            // "Pasif" simgeler önemli bir şey söylemiyor (Steam kapalıyken gibi)
            visible: modelData.status !== Status.Passive
            padding: 6
            active: root.bar.openMenu === menuKey

            function showMenu() {
                if (modelData.hasMenu)
                    root.bar.toggleMenu(menuKey);
            }

            onClicked: {
                if (modelData.onlyMenu)
                    showMenu();
                else
                    modelData.activate();
            }
            onRightClicked: showMenu()
            onMiddleClicked: modelData.secondaryActivate()
            onHoveredChanged: {
                if (hovered && modelData.hasMenu)
                    root.bar.hoverMenu(menuKey);
            }
            onScrolled: steps => modelData.scroll(steps * 120, false)

            IconImage {
                source: item.modelData.icon
                implicitSize: 16

                // Açık barda beyaz (tek renkli) simgeler kaybolmasın: çevresine ince koyu gölge.
                // Renkli simgelerde pek fark edilmez.
                layer.enabled: Colors.lightBar
                layer.effect: MultiEffect {
                    shadowEnabled: true
                    shadowColor: Colors.trayHalo
                    shadowBlur: 1
                    blurMax: 6
                    shadowHorizontalOffset: 0
                    shadowVerticalOffset: 0
                }
            }

            MenuPopup {
                controller: root.bar
                menuKey: item.menuKey
                anchorItem: item
                trayMenu: item.modelData.hasMenu ? item.modelData.menu : null
            }
        }
    }
}
