import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.theme
import qs.components

// Açılır menü: buzlu cam panel, satırlar ve alt menüler.
// Bar menüleri, sistem tepsisi ve dock bunu kullanır.
//
// entries dizisindeki her satır bir JS nesnesi:
//   text        satır yazısı
//   icon        theme/Icons.qml'deki simge adı           (isteğe bağlı)
//   layoutIcon  düzen simgesi: "dwindle" gibi             (isteğe bağlı)
//   image       resim adresi: uygulama ya da tepsi simgesi (isteğe bağlı)
//   shortcut    sağdaki soluk yazı: "Super F"            (isteğe bağlı)
//   checked     true/false: soldaki onay işareti; verilmezse satır işaretlenmez
//   enabled     false ise soluk ve tıklanmaz
//   separator   true ise ayırıcı çizgi
//   header      true ise küçük başlık (tıklanmaz)
//   submenu     alt menünün satırları (dizi)
//   trayMenu    sistem tepsisinden gelen alt menü
//   action      seçilince çağrılan fonksiyon
//
// Menü, bar gibi ayrı bir katman penceresi. Barın açılır penceresi (PopupWindow) olsaydı
// Hyprland onu ayrı bir kural olmadan bulanıklaştırmıyordu; katman penceresinde
// bulanık bölgeyi bar gibi kendisi bildiriyor.
PanelWindow {
    id: root

    property var entries: []
    // Verilirse satırlar sistem tepsisindeki uygulamanın menüsünden okunur (entries yerine)
    property var trayMenu: null

    // Menüyü bar yönetir: aynı anda tek menü açık, seçim ya da Esc hepsini kapatır.
    // controller: openMenu, menuOpened(), closeMenus() olan nesne (Bar.qml)
    property var controller: null
    property string menuKey: ""
    property bool open: controller !== null && controller.openMenu === menuKey
    property Item anchorItem: null
    // anchorItem'ın bulunduğu pencerenin ekrandaki sol üst köşesi.
    // Bar ekranın köşesinde (0, 0); alt menüde üst menünün konumu verilir.
    property point anchorOrigin: Qt.point(0, 0)
    property bool isSubmenu: false
    // Nereye açılsın: "below" öğenin altına (bar), "above" öğenin üstüne ve ortalı (dock)
    property string placement: "below"
    // "above" için öğeyle menü arasındaki boşluk
    property real anchorGap: Metrics.menuOffset
    // Tuşlar zincirin en üstündeki menüye gider; o da açık alt menüye iletir
    property var topMenu: root

    signal activated       // bir satır seçildi: bütün zincir kapanmalı
    signal escaped         // Esc: bütün zincir kapanmalı
    signal backRequested   // alt menüde sol ok: yalnızca bu alt menü kapanır

    property int currentIndex: -1   // vurgulu satır
    property int submenuIndex: -1   // alt menüsü açık satır

    readonly property var rows: trayMenu ? trayRows : entries
    // Onay sütunu yalnızca işaretli bir satır varken ayrılır (tasarımdaki gibi sade kalsın)
    readonly property bool hasChecks: rows.some(e => e.checked === true)
    readonly property bool hasIcons: rows.some(e => e.icon || e.layoutIcon || e.image)

    // Odak yakalama (HyprlandFocusGrab) için: bu menü ve açık alt menüsü
    readonly property var windows: visible ? [root].concat(sub.item?.windows ?? []) : []

    visible: open && anchorItem !== null
    color: "transparent"
    implicitWidth: panel.implicitWidth
    implicitHeight: panel.implicitHeight

    // Ekranın sol üst köşesine göre yerleşir; barın ayırdığı alanı yok sayar,
    // her şeyin üstünde durur (ada dahil), pencereleri itmez.
    screen: controller?.screen ?? null
    anchors {
        top: true
        left: true
    }
    margins.left: position.x
    margins.top: position.y
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "desk-menu"

    // Bar menüsü öğenin altına, sol kenarı hizalı açılır; ekrana sığmazsa sola kayar.
    // Alt menü satırın sağına açılır (ilk satırı üst menüdeki satırla aynı hizada);
    // sağda yer yoksa sola açılır.
    readonly property point position: {
        if (!open || !anchorItem)
            return Qt.point(0, 0);
        const p = anchorItem.mapToItem(null, 0, 0);
        const x = anchorOrigin.x + p.x;
        const y = anchorOrigin.y + p.y;
        const screenWidth = screen?.width ?? 1920;
        const screenHeight = screen?.height ?? 1080;
        const gap = Metrics.menuPadding + 2;

        if (isSubmenu) {
            let left = x + anchorItem.width + gap;
            if (left + implicitWidth > screenWidth)
                left = x - gap - implicitWidth;
            const top = Math.min(y - Metrics.menuPadding, screenHeight - implicitHeight);
            return Qt.point(Math.round(Math.max(0, left)), Math.round(Math.max(0, top)));
        }

        // Dock: öğenin üstünde, ortalı; ekrandan taşmaz
        if (placement === "above") {
            const centered = x + anchorItem.width / 2 - implicitWidth / 2;
            const above = y - anchorGap - implicitHeight;
            return Qt.point(Math.round(Math.max(4, Math.min(centered, screenWidth - implicitWidth - 4))), Math.round(Math.max(4, above)));
        }

        // Bar öğesi barın ortasında; menü barın alt kenarından menuOffset kadar aşağıda
        const top = y + anchorItem.height + (Metrics.barHeight - Metrics.barItemHeight) / 2 + Metrics.menuOffset;
        const left = Math.min(x, screenWidth - implicitWidth - 4);
        return Qt.point(Math.round(Math.max(4, left)), Math.round(top));
    }

    // Buzlu cam yalnızca yuvarlak panelin içinde (barınki gibi)
    BackgroundEffect.blurRegion: Region {
        item: panel
        radius: Metrics.menuRadius
    }

    onVisibleChanged: {
        currentIndex = -1;
        submenuIndex = -1;
    }

    onOpenChanged: controller?.menuOpened(root, open)
    onActivated: controller?.closeMenus()
    onEscaped: controller?.closeMenus()

    // --- Sistem tepsisi menüsü. Açıkken uygulamaya "menü açıldı" denir, o da içeriği günceller.
    QsMenuOpener {
        id: opener
        menu: root.open ? root.trayMenu : null
    }

    readonly property var trayRows: (opener.children?.values ?? []).map(e => ({
                text: e.text.replace(/<\/?u>/g, ""), // kısayol harfinin altı çizgisi kalksın
                separator: e.isSeparator,
                enabled: e.enabled,
                checked: e.buttonType === QsMenuButtonType.None ? undefined : e.checkState === Qt.Checked,
                image: e.icon,
                trayMenu: e.hasChildren ? e : null,
                action: () => e.triggered()
            }))

    // --- Satır seçimi
    function isSelectable(index) {
        const e = rows[index];
        return e !== undefined && !e.separator && !e.header && e.enabled !== false;
    }

    function hasSubmenu(index) {
        const e = rows[index];
        return e !== undefined && ((e.submenu?.length ?? 0) > 0 || (e.trayMenu ?? null) !== null);
    }

    function move(step) {
        if (rows.length === 0)
            return;
        // Hiçbir satır seçili değilken aşağı ok ilk, yukarı ok son satırdan başlar
        let i = currentIndex >= 0 ? currentIndex : (step > 0 ? -1 : rows.length);
        for (let n = 0; n < rows.length; n++) {
            i = (i + step + rows.length) % rows.length;
            if (isSelectable(i)) {
                currentIndex = i;
                return;
            }
        }
    }

    function trigger(index) {
        if (!isSelectable(index))
            return;
        if (hasSubmenu(index)) {
            openSubmenu(index);
            return;
        }
        // Önce menüler kapanır, sonra iş yapılır: odak uygulamaya dönmüş olur
        const action = rows[index].action;
        root.activated();
        if (action)
            action();
    }

    // Başka satırın alt menüsüne geçerken eskisi kapanıp yenisi açılır (vurgu ve klavye sıfırlansın)
    function openSubmenu(index) {
        if (submenuIndex === index)
            return;
        submenuIndex = -1;
        Qt.callLater(() => {
            if (root.visible && root.currentIndex === index)
                root.submenuIndex = index;
        });
    }

    // Klavye: oklar, Enter, Esc. Alt menü açıksa önce ona sorulur.
    function handleKey(event) {
        const child = sub.item;
        if (child && child.visible && child.currentIndex >= 0 && child.handleKey(event))
            return true;

        switch (event.key) {
        case Qt.Key_Escape:
            root.escaped();
            return true;
        case Qt.Key_Down:
            move(1);
            return true;
        case Qt.Key_Up:
            move(-1);
            return true;
        case Qt.Key_Right:
            if (hasSubmenu(currentIndex)) {
                openSubmenu(currentIndex);
                Qt.callLater(() => sub.item?.move(1));
            }
            return true;
        case Qt.Key_Left:
            if (isSubmenu)
                root.backRequested();
            return true;
        case Qt.Key_Return:
        case Qt.Key_Enter:
        case Qt.Key_Space:
            trigger(currentIndex);
            return true;
        }
        return false;
    }

    // Üstüne gelince alt menü kısa bir gecikmeyle açılır (fare çaprazlama geçerken titremesin)
    Timer {
        id: submenuTimer
        interval: 120
        onTriggered: {
            if (root.hasSubmenu(root.currentIndex))
                root.openSubmenu(root.currentIndex);
            else
                root.submenuIndex = -1;
        }
    }

    Rectangle {
        id: panel

        implicitWidth: Math.max(Metrics.menuMinWidth, list.implicitWidth + Metrics.menuPadding * 2)
        implicitHeight: list.implicitHeight + Metrics.menuPadding * 2
        width: root.width
        height: root.height
        radius: Metrics.menuRadius
        color: Colors.menu
        border.width: 1
        border.color: Colors.panelBorder

        GlassEdge {}

        // Tuşları yakalar (pencere klavye odağını aldığında)
        Item {
            anchors.fill: parent
            focus: true
            Keys.onPressed: event => event.accepted = root.topMenu.handleKey(event)
        }

        ColumnLayout {
            id: list

            anchors {
                fill: parent
                margins: Metrics.menuPadding
            }
            spacing: 0

            // Model satır sayısı: satırların içeriği değişince (onay işareti, pencere adı, Hyprland'den
            // gelen güncel bilgi) satırlar silinip baştan kurulmaz, yerinde güncellenir. Baştan
            // kurulsaydı fareyle basılıp bırakılırken altındaki satır değişir, tıklama kaybolurdu.
            Repeater {
                id: repeater
                model: root.rows.length

                delegate: MenuRow {
                    required property int index

                    Layout.fillWidth: true
                    entry: root.rows[index] ?? ({})
                    showCheck: root.hasChecks
                    showIcon: root.hasIcons
                    highlighted: root.currentIndex === index || root.submenuIndex === index

                    onHovered: {
                        root.currentIndex = index;
                        submenuTimer.restart();
                    }
                    onExited: {
                        // Alt menüye geçerken vurgu kalsın
                        if (root.currentIndex === index && root.submenuIndex !== index)
                            root.currentIndex = -1;
                    }
                    onClicked: {
                        root.currentIndex = index;
                        root.trigger(index);
                    }
                }
            }
        }
    }

    // --- Alt menü: aynı bileşen, gerektiğinde yüklenir
    LazyLoader {
        id: sub
        active: root.visible && root.submenuIndex >= 0
        source: Qt.resolvedUrl("MenuPopup.qml")
    }

    Binding {
        when: sub.item !== null
        target: sub.item
        property: "isSubmenu"
        value: true
    }
    Binding {
        when: sub.item !== null
        target: sub.item
        property: "topMenu"
        value: root.topMenu
    }
    Binding {
        when: sub.item !== null
        target: sub.item
        property: "entries"
        value: root.rows[root.submenuIndex]?.submenu ?? []
    }
    Binding {
        when: sub.item !== null
        target: sub.item
        property: "trayMenu"
        value: root.rows[root.submenuIndex]?.trayMenu ?? null
    }
    // Konum bilgileri "open"dan önce gelir: alt menü ekrana doğru yerde çıksın
    Binding {
        when: sub.item !== null
        target: sub.item
        property: "screen"
        value: root.screen
    }
    Binding {
        when: sub.item !== null
        target: sub.item
        property: "anchorOrigin"
        value: root.position
    }
    Binding {
        when: sub.item !== null
        target: sub.item
        property: "anchorItem"
        value: repeater.itemAt(root.submenuIndex)
    }
    Binding {
        when: sub.item !== null
        target: sub.item
        property: "open"
        value: true
    }

    Connections {
        target: sub.item
        ignoreUnknownSignals: true

        function onActivated() {
            root.activated();
        }
        function onEscaped() {
            root.escaped();
        }
        function onBackRequested() {
            root.submenuIndex = -1;
        }
    }
}
