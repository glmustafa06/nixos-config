import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.theme
import qs.components
import qs.services
import qs.modules.controlcenter
import qs.modules.notifications

// Üst bar: solda logo, uygulama adı ve menüler; ortada ada; sağda tepsi, durum simgeleri ve saat.
// Renkleri duvar kâğıdına uyar: açık duvar kâğıdında koyu yazı (Colors.bar*, scripts/bar_tone.py).
// Pencere bardan uzun, çünkü ada açılınca aşağı taşıyor. Boş kısım saydam ve
// tıklamaları alttaki pencerelere geçirir (mask). Pencereler yine barın altından başlar.
PanelWindow {
    id: root

    required property var modelData
    screen: modelData

    anchors {
        top: true
        left: true
        right: true
    }
    implicitHeight: Metrics.barWindowHeight
    exclusiveZone: Metrics.barHeight
    color: "transparent"

    WlrLayershell.namespace: "desk-bar"
    WlrLayershell.layer: WlrLayer.Top
    // Adada bildirime yanıt yazılırken klavye bara gelir (dışarı tıklanınca bırakılır); yoksa bar klavye almaz
    WlrLayershell.keyboardFocus: island.replying ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    // Fare yalnızca barın kendisini ve adayı görür
    mask: Region {
        item: barArea

        Region {
            item: island.shape
        }
    }

    // Buzlu cam: arkadaki her şeyi Hyprland bulanıklaştırır (yalnızca bar şeridi)
    BackgroundEffect.blurRegion: Region {
        item: background
    }

    // --- Menüler: aynı anda en fazla biri açık (kontrol merkezi ve bildirim merkezi de bunlardan).
    // Anahtarlar: "app", "window", "layout", "tray:<id>", "control-center", "notifications"
    property string openMenu: ""
    property var openPopup: null

    function toggleMenu(key) {
        openMenu = openMenu === key ? "" : key;
    }
    // Bir menü açıkken başka bir başlığın üstüne gelince o menüye geç
    function hoverMenu(key) {
        if (openMenu !== "" && openMenu !== key)
            openMenu = key;
    }
    function closeMenus() {
        openMenu = "";
    }
    function menuOpened(popup, isOpen) {
        if (isOpen)
            openPopup = popup;
        else if (openPopup === popup)
            openPopup = null;
    }

    // Kontrol merkezini aç ya da kapat. page: "main", "wifi", "bluetooth", "sound", "battery" …
    // Aynı simgeye tekrar basınca kapanır; başka simgeye basınca o sayfaya geçer.
    function toggleControlCenter(page) {
        if (openMenu === controlCenter.menuKey && controlCenter.rootPage === page) {
            closeMenus();
            return;
        }
        controlCenter.reset(page);
        openMenu = controlCenter.menuKey;
    }

    function openControlCenter(page) {
        if (openMenu === controlCenter.menuKey && controlCenter.page === page)
            return;
        controlCenter.reset(page);
        openMenu = controlCenter.menuKey;
    }

    ControlCenter {
        id: controlCenter
        controller: root
    }

    // Saate tıklayınca açılır
    NotificationCenter {
        id: notificationCenter
        controller: root
    }

    // Kısayollar (Super+S, IPC) yalnızca odaktaki ekranın barında açar
    function onFocusedScreen() {
        const focused = Hyprland.focusedMonitor;
        return !focused || !root.screen || focused.name === root.screen.name;
    }
    Connections {
        target: Ui
        function onControlCenterRequested(page) {
            if (root.onFocusedScreen())
                root.toggleControlCenter(page);
        }
        function onControlCenterOpenRequested(page) {
            if (root.onFocusedScreen())
                root.openControlCenter(page);
        }
        function onNotificationCenterRequested() {
            if (root.onFocusedScreen())
                root.toggleMenu(notificationCenter.menuKey);
        }
    }

    // Menü açıkken bar ve menü dışına tıklanınca Hyprland haber verir, menü kapanır.
    // Bu sırada bar ile menü normal çalışır (başlıklar arasında gezinmek gibi).
    HyprlandFocusGrab {
        active: root.openMenu !== ""
        windows: [root].concat(root.openPopup?.windows ?? [])
        onCleared: root.closeMenus()
    }

    // Adada yanıt yazılırken klavye bardadır; başka bir yere tıklanınca yanıt bırakılır
    // (yoksa klavye barda takılı kalırdı)
    HyprlandFocusGrab {
        active: island.replying
        windows: [root]
        onCleared: island.replying = false
    }

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    // ---------- Bar şeridi ----------
    Item {
        id: barArea

        anchors {
            top: parent.top
            left: parent.left
            right: parent.right
        }
        height: Metrics.barHeight

        // Klavye odağı bara gelirse (menü açıkken) tuşlar açık menüye gider
        focus: true
        Keys.onPressed: event => event.accepted = root.openPopup?.handleKey(event) ?? false

        Rectangle {
            id: background
            anchors.fill: parent
            color: Colors.barBackground

            // Alt kenardaki ince çizgi
            Rectangle {
                anchors {
                    left: parent.left
                    right: parent.right
                    bottom: parent.bottom
                }
                height: 1
                color: Colors.barBorder
            }
        }

        // --- Sol: logo, uygulama adı, Pencere, Düzen
        RowLayout {
            anchors {
                left: parent.left
                leftMargin: Metrics.barPadding
                verticalCenter: parent.verticalCenter
            }
            spacing: Metrics.barItemSpacing

            BarItem {
                padding: 8
                onClicked: Ui.searchRequested()

                OrbitLogo {
                    size: 18
                    color: Colors.barAccent
                }
            }

            MenuTitle {
                id: appTitle
                bar: root
                menuKey: "app"

                BarText {
                    text: WindowManager.appName
                    font.weight: Font.Bold
                }

                AppMenu {
                    controller: root
                    menuKey: appTitle.menuKey
                    anchorItem: appTitle
                }
            }

            MenuTitle {
                id: windowTitle
                bar: root
                menuKey: "window"
                enabled: WindowManager.hasWindow

                BarText {
                    text: "Pencere"
                }

                WindowMenu {
                    controller: root
                    menuKey: windowTitle.menuKey
                    anchorItem: windowTitle
                }
            }

            MenuTitle {
                id: layoutTitle
                bar: root
                menuKey: "layout"

                BarText {
                    text: "Düzen"
                }

                LayoutMenu {
                    controller: root
                    menuKey: layoutTitle.menuKey
                    anchorItem: layoutTitle
                }
            }
        }

        // --- Sağ: tepsi, durum simgeleri ve saat
        RowLayout {
            anchors {
                right: parent.right
                rightMargin: Metrics.barPadding
                verticalCenter: parent.verticalCenter
            }
            spacing: Metrics.barItemSpacing

            Tray {
                bar: root
                Layout.rightMargin: implicitWidth > 0 ? 6 : 0 // simge yoksa boşluk da olmasın
            }

            // Pil: yüzde ve simge
            BarItem {
                visible: BatteryStatus.present
                active: root.openMenu === controlCenter.menuKey && controlCenter.rootPage === "battery"
                onClicked: root.toggleControlCenter("battery")

                BarText {
                    text: Math.round(BatteryStatus.level * 100) + "%"
                    font.pixelSize: Typography.small + 1
                }
                BatteryIcon {
                    level: BatteryStatus.level
                    charging: BatteryStatus.charging
                    color: Colors.barText
                    accentColor: Colors.barAccent
                    warningColor: Colors.barWarning
                }
            }

            // Wi-Fi (kablo bağlıysa ağ simgesi); tıklayınca Wi-Fi listesi
            BarItem {
                active: root.openMenu === controlCenter.menuKey && controlCenter.rootPage === "wifi"
                onClicked: root.toggleControlCenter("wifi")

                WifiIcon {
                    visible: NetworkStatus.kind === "wifi"
                    strength: NetworkStatus.strength
                    color: Colors.barText
                }
                Icon {
                    visible: NetworkStatus.kind !== "wifi"
                    name: NetworkStatus.kind
                    color: NetworkStatus.kind === "wifi-off" ? Colors.barTextMuted : Colors.barText
                }
            }

            // Bluetooth: bir cihaz bağlıysa vurgu renginde; tıklayınca cihaz listesi
            BarItem {
                active: root.openMenu === controlCenter.menuKey && controlCenter.rootPage === "bluetooth"
                onClicked: root.toggleControlCenter("bluetooth")

                Icon {
                    name: BluetoothStatus.icon
                    color: BluetoothStatus.connected ? Colors.barAccent : BluetoothStatus.enabled ? Colors.barText : Colors.barTextMuted
                }
            }

            // Ses: tekerlekle düzey değişir; tıklayınca ayrıntılı ses menüsü
            BarItem {
                active: root.openMenu === controlCenter.menuKey && controlCenter.rootPage === "sound"
                onClicked: root.toggleControlCenter("sound")
                onScrolled: steps => AudioStatus.changeVolume(steps * 0.05)

                Icon {
                    name: AudioStatus.icon
                    color: Colors.barText
                }
            }

            // Klavye dili
            BarItem {
                BarText {
                    text: KeyboardLayout.code
                    font.pixelSize: Typography.small
                    font.weight: Font.DemiBold
                    font.letterSpacing: 0.4
                }
            }

            // Arama
            BarItem {
                onClicked: Ui.searchRequested()

                Icon {
                    name: "search"
                    size: 15
                    strokeWidth: 2.4
                    color: Colors.barText
                }
            }

            // Mikrofon kullanılıyorsa turuncu nokta (macOS'taki gibi)
            Rectangle {
                visible: AudioStatus.micInUse
                Layout.leftMargin: 4
                Layout.rightMargin: 2
                implicitWidth: 7
                implicitHeight: 7
                radius: 3.5
                color: Colors.barWarning
            }

            // Kontrol merkezi
            BarItem {
                active: root.openMenu === controlCenter.menuKey && controlCenter.rootPage === "main"
                onClicked: root.toggleControlCenter("main")

                ControlCenterIcon {
                    color: Colors.barText
                }
            }

            // Tarih ve saat ("Sal 17 Kas  18:40"); tıklayınca bildirim merkezi.
            // Rahatsız etme açıkken başında ay.
            BarItem {
                active: root.openMenu === notificationCenter.menuKey
                onClicked: root.toggleMenu(notificationCenter.menuKey)

                Icon {
                    visible: QuickSettings.doNotDisturb
                    name: "moon"
                    size: 14
                    strokeWidth: 2.4
                    color: Colors.barText
                }
                BarText {
                    text: clock.date.toLocaleString(Qt.locale("tr_TR"), "ddd d MMM  HH:mm")
                }
            }
        }
    }

    // ---------- Orta: ada (barın üstünde, açılınca aşağı taşar) ----------
    // Tam genişlikte durur; şekil ortada büyüyüp küçülür. Böylece maske her karede doğru yerde kalır.
    Island {
        id: island
        anchors {
            top: parent.top
            left: parent.left
            right: parent.right
        }
    }
}
