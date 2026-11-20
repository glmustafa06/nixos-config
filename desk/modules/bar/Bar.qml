import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Services.SystemTray
import qs.theme
import qs.components
import qs.services
import qs.modules.controlcenter
import qs.modules.notifications
import qs.settings

// Üst bar: solda dört nokta (arama), uygulama adı ve menüler; ortada ada; sağda tepsi, durum simgeleri ve saat.
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
        function onCalendarRequested(day) {
            if (!root.onFocusedScreen())
                return;
            root.openMenu = notificationCenter.menuKey;
            notificationCenter.showDay(day);
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
        precision: root.barSettings.seconds ? SystemClock.Seconds : SystemClock.Minutes
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

        // --- Sol: dört nokta (arama), uygulama adı, Pencere, Düzen
        RowLayout {
            anchors {
                left: parent.left
                leftMargin: Metrics.barPadding
                verticalCenter: parent.verticalCenter
            }
            spacing: Metrics.barItemSpacing

            // Sol üst: dört nokta (barın yazı renginde); tıklayınca arama
            BarItem {
                padding: 8
                onClicked: Ui.searchRequested()

                Grid {
                    columns: 2
                    spacing: 3

                    Repeater {
                        model: 4

                        Rectangle {
                            width: 5
                            height: 5
                            radius: 2.5
                            color: Colors.barText
                        }
                    }
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
                visible: root.barSettings.menus

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
                visible: root.barSettings.menus

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

        // --- Sağ: sıra ve görünenler Ayarlar → Üst bar'dan (Settings.barItems). Varsayılan macOS'taki gibi:
        //   tepsi | klavye dili | Bluetooth, ses, pil, Wi-Fi | arama, (mikrofon), kontrol merkezi | saat
        // Farklı gruptan iki öğe yan yana gelince araya biraz boşluk girer.
        RowLayout {
            anchors {
                right: parent.right
                rightMargin: Metrics.barPadding
                verticalCenter: parent.verticalCenter
            }
            spacing: Metrics.barItemSpacing

            Repeater {
                model: root.rightItems

                delegate: Loader {
                    required property var modelData
                    required property int index

                    visible: root.available(modelData.id)
                    Layout.rightMargin: root.gapAfter(index)
                    sourceComponent: ({
                            tray: trayItem,
                            keyboard: keyboardItem,
                            bluetooth: bluetoothItem,
                            sound: soundItem,
                            battery: batteryItem,
                            wifi: wifiItem,
                            search: searchItem,
                            controlcenter: controlCenterItem,
                            clock: clockItem
                        })[modelData.id] ?? null
                }
            }
        }
    }

    // ---------- Sağdaki öğelerin sırası ----------
    // Gizlenenler (Ayarlar) modelde yok; donanımı olmayanlar (pil) ve boş tepsi görünmez
    readonly property var rightItems: Settings.barItems.filter(item => item.shown)

    function available(id) {
        if (id === "battery")
            return BatteryStatus.present;
        if (id === "tray")
            return SystemTray.items.values.some(item => item.status !== Status.Passive);
        return true;
    }

    // Kendisinden sonra görünen ilk öğe başka gruptansa araya boşluk
    function gapAfter(index) {
        const items = rightItems;
        if (!available(items[index]?.id ?? ""))
            return 0;
        for (let i = index + 1; i < items.length; i++) {
            if (!available(items[i].id))
                continue;
            const group = id => Settings.barItemInfo[id]?.group ?? id;
            return group(items[i].id) !== group(items[index].id) ? Metrics.barGroupGap : 0;
        }
        return 0;
    }

    // Saat: "Sal 17 Kas  18:40" (Ayarlar → Üst bar → gün, tarih, saniye)
    readonly property var barSettings: Settings.s.bar
    readonly property string clockFormat: {
        const parts = [];
        if (barSettings.weekday)
            parts.push("ddd");
        if (barSettings.date)
            parts.push("d MMM");
        const day = parts.join(" ");
        const time = barSettings.seconds ? "HH:mm:ss" : "HH:mm";
        return day === "" ? time : day + "  " + time;
    }

    Component {
        id: trayItem
        Tray {
            bar: root
        }
    }

    // Klavye dili
    Component {
        id: keyboardItem
        BarItem {
            BarText {
                text: KeyboardLayout.code
                font.pixelSize: Typography.small
                font.weight: Font.DemiBold
                font.letterSpacing: 0.4
            }
        }
    }

    // Bluetooth: bağlıyken simgesi değişir; tıklayınca cihaz listesi
    Component {
        id: bluetoothItem
        BarItem {
            active: root.openMenu === controlCenter.menuKey && controlCenter.rootPage === "bluetooth"
            onClicked: root.toggleControlCenter("bluetooth")

            Icon {
                name: BluetoothStatus.icon
                size: Metrics.barIconSize
                strokeWidth: Metrics.barIconStroke
                color: BluetoothStatus.enabled ? Colors.barText : Colors.barTextMuted
            }
        }
    }

    // Ses: tekerlekle düzey değişir; tıklayınca ayrıntılı ses menüsü
    Component {
        id: soundItem
        BarItem {
            active: root.openMenu === controlCenter.menuKey && controlCenter.rootPage === "sound"
            onClicked: root.toggleControlCenter("sound")
            onScrolled: steps => AudioStatus.changeVolume(steps * 0.05)

            Icon {
                name: AudioStatus.icon
                size: Metrics.barIconSize
                strokeWidth: Metrics.barIconStroke
                color: Colors.barText
            }
        }
    }

    // Pil: yüzde (Ayarlar'dan gizlenebilir) ve simge
    Component {
        id: batteryItem
        BarItem {
            active: root.openMenu === controlCenter.menuKey && controlCenter.rootPage === "battery"
            onClicked: root.toggleControlCenter("battery")

            BarText {
                visible: root.barSettings.batteryPercent
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
    }

    // Wi-Fi (kablo bağlıysa ağ simgesi); tıklayınca Wi-Fi listesi
    Component {
        id: wifiItem
        BarItem {
            active: root.openMenu === controlCenter.menuKey && controlCenter.rootPage === "wifi"
            onClicked: root.toggleControlCenter("wifi")

            WifiIcon {
                visible: NetworkStatus.kind === "wifi"
                strength: NetworkStatus.strength
                size: Metrics.barIconSize
                strokeWidth: Metrics.barIconStroke
                color: Colors.barText
            }
            Icon {
                visible: NetworkStatus.kind !== "wifi"
                name: NetworkStatus.kind
                size: Metrics.barIconSize
                strokeWidth: Metrics.barIconStroke
                color: NetworkStatus.kind === "wifi-off" ? Colors.barTextMuted : Colors.barText
            }
        }
    }

    // Arama
    Component {
        id: searchItem
        BarItem {
            onClicked: Ui.searchRequested()

            Icon {
                name: "search"
                size: Metrics.barIconSize - 1
                strokeWidth: Metrics.barIconStroke + 0.2
                color: Colors.barText
            }
        }
    }

    // Kontrol merkezi; mikrofon kullanılıyorsa yanında turuncu nokta (macOS'taki gibi)
    Component {
        id: controlCenterItem
        BarItem {
            active: root.openMenu === controlCenter.menuKey && controlCenter.rootPage === "main"
            onClicked: root.toggleControlCenter("main")

            Rectangle {
                visible: AudioStatus.micInUse
                implicitWidth: 6
                implicitHeight: 6
                radius: 3
                color: Colors.barWarning
            }
            ControlCenterIcon {
                color: Colors.barText
            }
        }
    }

    // Tarih ve saat; tıklayınca bildirim merkezi. Rahatsız etme açıkken başında ay.
    Component {
        id: clockItem
        BarItem {
            active: root.openMenu === notificationCenter.menuKey
            onClicked: root.toggleMenu(notificationCenter.menuKey)

            Icon {
                visible: QuickSettings.doNotDisturb
                name: "moon"
                size: Metrics.barIconSize - 2
                strokeWidth: Metrics.barIconStroke + 0.2
                color: Colors.barText
            }
            BarText {
                text: clock.date.toLocaleString(Qt.locale("tr_TR"), root.clockFormat)
                // Saniye görünürken rakamlar eşit genişlikte (saat titremesin)
                font.features: root.barSettings.seconds ? {
                    "tnum": 1
                } : {}
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
