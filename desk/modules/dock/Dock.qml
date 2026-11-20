import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Widgets
import qs.theme
import qs.components
import qs.services
import qs.settings

// Dock: ekranın altında ortada, menülerle aynı buzlu camdan.
// Sırayla: sabitlenen uygulamalar | sabitlenmemiş açık uygulamalar | İndirilenler, çöp kutusu.
//
// Akıllı gizleme: o alandaki bir pencere dock'un yerine girince kayarak gizlenir;
// fare ekranın alt kenarına gelince çıkar. Boş masaüstünde hep görünür.
// Ayarlar → Dock: "Hep görünür" (pencereler dock'un üstünde biter) ya da "Hep gizli" (yalnızca
// fare alt kenara gelince çıkar). Simge boyu, İndirilenler/çöp, rozetler ve noktalar da oradan.
//
// Sürükleyerek sıralama: sabitlenen bir simge sürüklenince fareyi izler, ötekiler kayarak yer açar.
// Açık ama sabitlenmemiş bir uygulama sabitlenenlerin arasına bırakılırsa sabitlenir. Dock'un çok
// üstünde bırakılırsa vazgeçilir (simge yerine döner).
//
// Dosya bırakma: Dolphin'den sürüklenen dosya bir uygulamanın simgesine bırakılırsa onunla açılır
// (dosya açamayan uygulama vurgulanmaz), çöp kutusuna bırakılırsa çöpe taşınır. Dock gizliyse dosya
// ekranın alt kenarına getirilince çıkar.
//
// Rozet: uygulamanın görülmemiş bildirim sayısı (Notifications.badges).
//
// İki pencere var:
//  - dock penceresi: tam genişlikte; dock, ad etiketi ve sağ tık menüsü bunun içinde.
//    Yalnızca dock'un kendisi (ve açıkken menü) tıklama alır; gerisi saydam ve tıklamaları
//    alttaki pencerelere geçirir (mask). Dock gizlenince kayma bitince pencere de kapanır:
//    açık kalsaydı Hyprland boş kalan bulanık bölgeyi bütün pencereye uyguluyordu (Sorun 59).
//  - alt kenar şeridi: 2 piksellik görünmez pencere, hep açık; fare gelince dock'u çıkarır.
PanelWindow {
    id: root

    required property var modelData
    screen: modelData

    anchors {
        bottom: true
        left: true
        right: true
    }
    implicitHeight: Metrics.dockWindowHeight
    // Gösterilirken ya da kayarak gizlenirken açık; tamamen gizlenince kapanır
    visible: shown || panel.y < height
    // Hep görünürken pencereler dock'un üstünde biter (dock'un yeri ayrılır)
    readonly property string behavior: Settings.s.dock.behavior
    exclusionMode: behavior === "always" ? ExclusionMode.Normal : ExclusionMode.Ignore
    exclusiveZone: behavior === "always" ? Metrics.dockHeight + Metrics.dockMargin : 0
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "desk-dock"

    // Fareyi yalnızca dock, altındaki boşluk ve açıkken menü alır
    mask: Region {
        item: panel

        Region {
            item: belowPanel
        }
        Region {
            item: menu.open ? menu : null
        }
    }

    BackgroundEffect.blurRegion: Region {
        item: panel
        radius: Metrics.dockRadius

        Region {
            item: menu.open ? menu : null
            radius: Metrics.menuRadius
        }
    }

    // --- Öğeler
    // Sürüklerken sabitlenenler geçici sırayla gösterilir (dragOrder). Sürükleme boyunca ayırıcı yerinde
    // kalır: dock'un genişliği değişip simgeler kaymasın.
    // Hepsi tek bağlamada hesaplanır: ara özellikler ayrı güncellenseydi bir an aynı anahtar iki kez
    // görünebilirdi (ScriptModel'in sırası bozulur).
    readonly property var keys: {
        const pinned = dragOrder ?? DockApps.pinnedKeys;
        const running = DockApps.runningKeys.filter(key => !pinned.includes(key));
        const list = pinned.slice();
        if (running.length > 0 || (dragKey !== "" && DockApps.runningKeys.length > 0))
            list.push("sep:apps", ...running);
        if (Settings.s.dock.places)
            list.push("sep:places", "place:downloads", "place:trash");
        return list.filter((key, index) => list.indexOf(key) === index);
    }

    // Dock'taki simge (anahtarına göre); yoksa null
    function itemFor(key) {
        for (const child of row.children) {
            if (child.key === key && child.dock !== undefined)
                return child;
        }
        return null;
    }

    // --- Sürükleyerek sıralama
    property string dragKey: ""         // sürüklenen simge ("" sürükleme yok)
    property var dragOrder: null        // sürüklerken sabitlenenlerin geçici sırası
    property bool dragSettling: false   // bırakıldı: simge yerine kayıyor
    property point dragPoint            // sürüklenen simgenin ortası (content'e göre)
    property point dragGrab             // farenin simgenin ortasına uzaklığı
    property string dragIcon: ""
    // Dock'un bu kadar üstünde bırakılırsa vazgeçilir
    readonly property int dragCancelDistance: 90
    readonly property bool dragCanceling: dragKey !== "" && !dragSettling && dragPoint.y < panel.y - dragCancelDistance

    // item: sürüklenmeye başlanan DockItem; x, y: farenin item'deki yeri. Sürüklenemiyorsa false.
    function beginDrag(item, x, y) {
        if (item.separator || item.place || dragKey !== "")
            return false;
        closeMenus();
        hoveredItem = null;
        labelItem = null;
        const center = item.mapToItem(content, item.width / 2, item.height / 2);
        const point = item.mapToItem(content, x, y);
        dragGrab = Qt.point(point.x - center.x, point.y - center.y);
        dragPoint = center;
        dragIcon = item.iconSource;
        dragOrder = DockApps.pinnedKeys.slice();
        dragKey = item.key;
        return true;
    }

    function moveDrag(item, x, y) {
        if (dragKey === "" || dragSettling)
            return;
        const point = item.mapToItem(content, x, y);
        dragPoint = Qt.point(point.x - dragGrab.x, point.y - dragGrab.y);

        // Sürüklenen simgenin ortası dock'un hangi yuvasında (sabitlenenler soldan eşit aralıkla dizili)
        const slot = Metrics.dockIconSize + Metrics.dockSpacing;
        const local = row.mapFromItem(content, dragPoint.x, 0).x;
        const others = dragOrder.filter(key => key !== dragKey);
        const pinned = DockApps.pinnedKeys.includes(dragKey);
        let order = others.slice();
        // Sabitlenmemiş uygulama: yalnızca sabitlenenlerin üstüne (ayırıcının yarısına kadar) gelince araya girer
        if (pinned || local < others.length * slot + slot / 2)
            order.splice(Math.max(0, Math.min(Math.floor(local / slot), others.length)), 0, dragKey);
        if (order.join("\n") !== dragOrder.join("\n"))
            dragOrder = order;
    }

    function endDrag() {
        if (dragKey === "" || dragSettling)
            return;
        if (dragCanceling)
            dragOrder = DockApps.pinnedKeys.slice();
        // Simge dock'taki yerine kayar, sonra sıra kaydedilir
        dragSettling = true;
        dragPoint = slotCenter(dragKey);
        settleTimer.restart();
    }

    // Sürüklenen simge dock'tan kalktı (uygulama sürüklenirken kapandı): iz bırakmadan bırak
    function cancelDrag() {
        settleTimer.stop();
        dragOrder = null;
        dragKey = "";
        dragSettling = false;
    }

    // Anahtarın dock'taki yerinin ortası (content'e göre). Row'un yerleşimini beklemeden hesaplanır.
    function slotCenter(key) {
        let x = 0;
        for (const k of keys) {
            const width = k.startsWith("sep:") ? Metrics.dockSeparatorWidth : Metrics.dockIconSize;
            if (k === key)
                return row.mapToItem(content, x + width / 2, row.height / 2);
            x += width + Metrics.dockSpacing;
        }
        return dragPoint;
    }

    Timer {
        id: settleTimer
        interval: Metrics.durationFast + 20
        onTriggered: {
            const order = root.dragOrder;
            if (order && order.join("\n") !== DockApps.pinnedKeys.join("\n"))
                DockApps.setPinnedOrder(order);
            root.dragOrder = null;
            root.dragKey = "";
            root.dragSettling = false;
        }
    }

    // --- Dosya bırakma
    property string dropKey: ""         // dosya sürüklenirken altındaki (dosyayı kabul eden) simge

    // Bırakılan adresler: yerel dosyalar yol olarak, ötekiler (bağlantılar) olduğu gibi
    function dropPaths(urls) {
        return Array.from(urls ?? []).map(String).map(url => url.startsWith("file://") ? decodeURIComponent(url.replace(/^file:\/\/(localhost)?/, "")) : url);
    }

    function canDrop(key) {
        if (key === "place:trash")
            return true;
        if (key === "" || key.startsWith("sep:") || key.startsWith("place:"))
            return false;
        return DockApps.canOpenFiles(key);
    }

    function updateDrop(x, y) {
        const local = dropArea.mapToItem(row, x, y);
        const key = row.childAt(local.x, row.height / 2)?.key ?? "";
        dropKey = canDrop(key) ? key : "";
    }

    function finishDrop(urls) {
        const key = dropKey;
        dropKey = "";
        const paths = dropPaths(urls);
        if (key === "" || paths.length === 0)
            return false;
        if (key === "place:trash") {
            const files = paths.filter(path => path.startsWith("/"));
            Trash.trashFiles(files);
            return files.length > 0;
        }
        const item = itemFor(key);
        if (item && !item.running)
            item.startLaunching();
        DockApps.openWith(key, paths);
        return true;
    }

    // Dosya alt kenara gelince dock bir süre görünür (dock'un üstüne çıkılınca orası tutar)
    Timer {
        id: dropRevealTimer
        interval: 1500
    }

    // --- Menü: dock penceresinin içinde, aynı anda tek menü
    property string openMenu: ""    // "" ya da "dock"
    readonly property string menuKeyOpen: openMenu !== "" ? menu.key : ""

    // Aynı öğede tekrar basınca kapanır; başka öğeye basınca menü oraya geçer
    function showMenu(key, item) {
        if (openMenu !== "" && menu.key === key) {
            closeMenus();
            return;
        }
        menu.key = key;
        const center = item.mapToItem(content, item.width / 2, 0).x;
        menu.x = Math.round(Math.max(4, Math.min(center - menu.width / 2, content.width - menu.width - 4)));
        openMenu = "dock";
    }
    function closeMenus() {
        openMenu = "";
    }

    // Menü açıkken dışarı tıklanınca (başka pencere, bar…) Hyprland haber verir, menü kapanır.
    // Menü dock'la aynı pencerede olduğu için listede tek pencere var.
    HyprlandFocusGrab {
        active: root.openMenu !== ""
        windows: [root]
        onCleared: root.closeMenus()
    }

    // --- Ad etiketi: üstüne gelinen simgenin adı.
    // Fare simgeden çıkınca etiket hemen gitmez (simgeler arasındaki boşlukta titremesin);
    // başka simgeye geçilirse oraya taşınır, geçilmezse kısa bir süre sonra yerinde solar.
    property DockItem hoveredItem: null
    property DockItem labelItem: null

    function hoverItem(item, on) {
        if (on) {
            labelTimer.stop();
            hoveredItem = item;
            labelItem = item;
        } else if (hoveredItem === item) {
            hoveredItem = null;
            labelTimer.restart();
        }
    }

    Timer {
        id: labelTimer
        interval: 150
        onTriggered: root.labelItem = null
    }

    // --- Akıllı gizleme
    readonly property var monitor: Hyprland.monitorFor(screen)
    readonly property var workspace: monitor?.activeWorkspace ?? null

    // Dock'un ekrandaki yeri, Hyprland'in koordinatlarıyla (gösterilirkenki hâli)
    readonly property real monitorX: monitor?.x ?? monitor?.lastIpcObject?.x ?? 0
    readonly property real monitorY: monitor?.y ?? monitor?.lastIpcObject?.y ?? 0
    readonly property rect dockRect: Qt.rect(monitorX + (width - panel.width) / 2, monitorY + (screen?.height ?? 1080) - Metrics.dockMargin - Metrics.dockHeight, panel.width, Metrics.dockHeight)

    function onThisWorkspace(toplevel) {
        const info = toplevel.lastIpcObject ?? {};
        return info.pinned === true || (toplevel.workspace ?? null) === workspace;
    }

    // Bu alandaki bir pencere dock'un yerine giriyor mu (tam ekran pencere her zaman girer).
    // Hep görünürken hiç, hep gizliyken her zaman "giriyor" sayılır.
    readonly property bool overlapped: {
        if (behavior === "always")
            return false;
        if (behavior === "autohide")
            return true;
        if (!workspace)
            return false;
        const r = dockRect;
        for (const toplevel of Hyprland.toplevels.values) {
            if (!onThisWorkspace(toplevel))
                continue;
            const info = toplevel.lastIpcObject ?? {};
            if (info.hidden)
                continue;
            if ((info.fullscreen ?? 0) !== 0)
                return true;
            const at = info.at ?? [0, 0];
            const size = info.size ?? [0, 0];
            if (at[0] < r.x + r.width && at[0] + size[0] > r.x && at[1] < r.y + r.height && at[1] + size[1] > r.y)
                return true;
        }
        return false;
    }

    // Hyprland yüzen pencere sürüklenirken haber vermiyor; böyle bir pencere varken ara ara sorulur.
    // Fare dock'tayken ya da menü açıkken dock zaten görünür; sormaya gerek yok.
    readonly property bool hasFloating: Hyprland.toplevels.values.some(t => onThisWorkspace(t) && t.lastIpcObject?.floating === true)
    Timer {
        running: root.hasFloating && !root.hovering && root.openMenu === ""
        interval: 1000
        repeat: true
        onTriggered: Hyprland.refreshToplevels()
    }

    // Fare dock'un ya da alt kenar şeridinin üstünde
    readonly property bool hovering: hover.hovered || edgeHover.hovered
    readonly property bool wanted: !overlapped || hovering || openMenu !== "" || dragKey !== "" || dropArea.containsDrag || dropRevealTimer.running
    property bool shown: true

    onWantedChanged: {
        if (wanted) {
            hideTimer.stop();
            shown = true;
        } else {
            hideTimer.restart();
        }
    }
    Component.onCompleted: shown = wanted

    Timer {
        id: hideTimer
        interval: Metrics.dockHideDelay
        onTriggered: root.shown = root.wanted
    }

    // Çöp kutusu dolu mu: dock görünürken ara ara bakılır
    onShownChanged: {
        if (shown)
            Trash.refresh();
    }
    Timer {
        running: root.shown
        interval: 15000
        repeat: true
        onTriggered: Trash.refresh()
    }

    // ---------- İçerik ----------
    Item {
        id: content
        anchors.fill: parent

        HoverHandler {
            id: hover
        }

        // Dock ile ekranın alt kenarı arası (fare buradan geçerken dock kaçmasın)
        Item {
            id: belowPanel
            x: panel.x
            y: panel.y + panel.height
            width: panel.width
            height: Math.max(0, root.height - y)
        }

        // Dosya bırakma: dock ve altındaki boşluk. Bırakma kabul edilir ama dosya yalnızca kabul eden
        // simgenin üstündeyse kullanılır (kaynak program dosyaya dokunmaz: kopyala eylemi).
        DropArea {
            id: dropArea

            x: panel.x
            y: panel.y
            width: panel.width
            height: Math.max(0, root.height - y)
            keys: ["text/uri-list"]

            onEntered: drag => {
                drag.accept(Qt.CopyAction);
                root.updateDrop(drag.x, drag.y);
            }
            onPositionChanged: drag => root.updateDrop(drag.x, drag.y)
            onExited: root.dropKey = ""
            onDropped: drop => {
                if (root.finishDrop(drop.urls))
                    drop.accept(Qt.CopyAction);
                else
                    drop.accepted = false;
            }
        }

        // Altında yumuşak gölge: dock'u duvar kâğıdından hafifçe ayırır (abartısız)
        RectangularShadow {
            anchors.fill: panel
            radius: panel.radius
            blur: 26
            spread: -4
            offset.y: 5
            color: Colors.dockShadow
        }

        Rectangle {
            id: panel

            anchors.horizontalCenter: parent.horizontalCenter
            y: root.shown ? root.height - Metrics.dockMargin - height : root.height + 6
            width: row.implicitWidth + Metrics.dockPadding * 2
            height: Metrics.dockHeight
            radius: Metrics.dockRadius
            color: Colors.glass
            border.width: 1
            border.color: Colors.panelBorder

            GlassEdge {}

            Behavior on y {
                NumberAnimation {
                    duration: Metrics.durationDock
                    easing.type: Easing.OutCubic
                }
            }
            Behavior on width {
                NumberAnimation {
                    duration: Metrics.durationFast
                    easing.type: Easing.OutCubic
                }
            }

            Row {
                id: row

                anchors.centerIn: parent
                spacing: Metrics.dockSpacing

                // Uygulama açılınca yeni simge belirir, ötekiler kayarak yer açar
                add: Transition {
                    NumberAnimation {
                        property: "opacity"
                        from: 0
                        to: 1
                        duration: Metrics.durationNormal
                    }
                }
                move: Transition {
                    NumberAnimation {
                        property: "x"
                        duration: Metrics.durationFast
                        easing.type: Easing.OutCubic
                    }
                }

                // ScriptModel: pencere açılıp kapandıkça simgeler baştan kurulmaz
                Repeater {
                    model: ScriptModel {
                        values: root.keys
                    }

                    delegate: DockItem {
                        dock: root
                    }
                }
            }
        }

        // Sürüklenen simge: fareyi izler; bırakılınca dock'taki yerine kayar
        IconImage {
            id: ghost

            visible: root.dragKey !== ""
            implicitSize: Metrics.dockIconSize
            source: root.dragIcon
            x: root.dragPoint.x - width / 2
            y: root.dragPoint.y - height / 2
            scale: root.dragSettling ? 1 : 1.08
            // Vazgeçilecek yükseklikte soluk
            opacity: root.dragCanceling ? 0.5 : 1

            Behavior on x {
                enabled: root.dragSettling
                NumberAnimation {
                    duration: Metrics.durationFast
                    easing.type: Easing.OutCubic
                }
            }
            Behavior on y {
                enabled: root.dragSettling
                NumberAnimation {
                    duration: Metrics.durationFast
                    easing.type: Easing.OutCubic
                }
            }
            Behavior on scale {
                NumberAnimation { duration: Metrics.durationFast }
            }
            Behavior on opacity {
                NumberAnimation { duration: Metrics.durationFast }
            }
        }

        // Sağ tık menüsü: tıklanan simgenin üstünde, ortalı (x, showMenu'de hesaplanır)
        DockMenu {
            id: menu
            open: root.openMenu !== ""
            y: panel.y - height - Metrics.dockPadding - 6
            onCloseRequested: root.closeMenus()
        }

        // Ad etiketi (menü açıkken gizli). Yeri ve yazısı yalnızca yeni bir simgeye geçince
        // değişir; solarken olduğu yerde kalır.
        Rectangle {
            id: label

            readonly property bool active: root.labelItem !== null && root.openMenu === "" && root.shown && root.dragKey === ""
            property string title: ""

            Connections {
                target: root
                function onLabelItemChanged() {
                    const item = root.labelItem;
                    if (!item)
                        return;
                    label.title = item.title;
                    const center = item.mapToItem(content, item.width / 2, 0).x;
                    label.x = Math.round(Math.max(4, Math.min(center - label.width / 2, content.width - label.width - 4)));
                }
            }

            y: panel.y - height - 8
            width: labelText.implicitWidth + 20
            height: 26
            radius: 8
            color: Colors.tooltip
            border.width: 1
            border.color: Colors.panelBorder
            opacity: active ? 1 : 0
            visible: opacity > 0

            Behavior on opacity {
                NumberAnimation { duration: Metrics.durationFast }
            }

            Text {
                id: labelText
                anchors.centerIn: parent
                text: label.title
                color: Colors.text
                font.family: Typography.family
                font.pixelSize: Typography.small + 1
                font.weight: Font.Medium
            }
        }
    }

    // ---------- Alt kenar şeridi ----------
    // Ayrı, hep açık, görünmez bir pencere: dock gizliyken fare ekranın altına gelince çıkarır.
    PanelWindow {
        screen: root.screen
        anchors {
            bottom: true
            left: true
            right: true
        }
        implicitHeight: 2
        exclusionMode: ExclusionMode.Ignore
        color: "transparent"
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.namespace: "desk-dock-edge"

        Item {
            anchors.fill: parent

            HoverHandler {
                id: edgeHover
            }

            // Dosya sürüklenirken alt kenara gelinince dock çıkar (bırakma dock'ta yapılır)
            DropArea {
                anchors.fill: parent
                keys: ["text/uri-list"]
                onEntered: dropRevealTimer.restart()
                onPositionChanged: dropRevealTimer.restart()
            }
        }
    }
}
