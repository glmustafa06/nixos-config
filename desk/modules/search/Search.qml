import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Widgets
import qs.theme
import qs.components
import qs.services

// Arama (Spotlight gibi): ekranın üst kısmında, ortada tek kutu.
// Boşken son kullanılanlar, yazınca sonuçlar (Launcher.qml). Oklar gezer, Enter açar,
// Ctrl+Enter dosyayı klasöründe gösterir, Esc önce yazıyı siler, sonra kapatır.
// Pano hâli (Super+V): kopyalananlar, en yenisi başta; yazınca süzülür, Enter kopyalar, Delete siler.
// En çok 8 satır görünür; daha fazlası oklarla ve tekerlekle kayar.
//
// Pencere en uzun hâli kadar ama yalnızca panel tıklama alır (mask); dışarı tıklanınca
// Hyprland haber verir, arama kapanır. Açılış/kapanış animasyonu Hyprland'de (rules.lua).
PanelWindow {
    id: root

    required property var modelData
    screen: modelData

    property bool open: false
    property int currentIndex: 0
    // Görünen ilk satır (8'den çok sonuç varsa kaydırma)
    property int first: 0
    readonly property int rows: Metrics.searchRows
    readonly property bool clipboard: Launcher.mode === "clipboard"
    // Farenin son yeri: seçim yalnızca fare gerçekten oynayınca değişir. Yoksa arama, imlecin
    // hemen altında açıldığında ya da sonuçlar imlecin altında değiştiğinde seçim kendiliğinden
    // kayar, Enter yanlış sonucu açardı.
    property point lastMouse: Qt.point(-1, -1)

    readonly property var results: Launcher.results
    readonly property var shown: results.slice(first, first + rows)

    function toggle() {
        if (open)
            close();
        else
            show("search");
    }
    // mode: "search" ya da "clipboard"
    function show(mode) {
        Launcher.mode = mode;
        if (mode === "clipboard")
            Clipboard.refresh();
        input.text = "";
        Launcher.query = "";
        currentIndex = 0;
        first = 0;
        lastMouse = Qt.point(-1, -1);
        open = true;
    }
    function close() {
        open = false;
    }

    // Seçilen sonuç: önce arama kapanır (odak uygulamaya döner), sonra iş yapılır
    function run(index, alt) {
        const item = results[index];
        if (!item || item.enabled === false)
            return;
        close();
        Qt.callLater(() => Launcher.activate(item, alt));
    }

    function move(step) {
        if (results.length === 0)
            return;
        let i = currentIndex;
        for (let n = 0; n < results.length; n++) {
            i = (i + step + results.length) % results.length;
            if (results[i].enabled !== false) {
                select(i);
                return;
            }
        }
    }

    // Seç ve görünür yap
    function select(i) {
        currentIndex = i;
        if (i < first)
            first = i;
        else if (i >= first + rows)
            first = i - rows + 1;
    }

    // Tekerlek: liste kayar, seçim görünür kalır
    function scroll(step) {
        first = Math.max(0, Math.min(first + step, results.length - rows));
        if (currentIndex < first)
            currentIndex = first;
        else if (currentIndex >= first + rows)
            currentIndex = first + rows - 1;
    }

    // Pano hâlinde seçili kaydı sil
    function removeSelected() {
        const item = results[currentIndex];
        if (item?.kind !== "clip")
            return;
        Clipboard.remove(item.entry);
        Qt.callLater(() => {
            if (root.currentIndex >= root.results.length)
                root.select(Math.max(0, root.results.length - 1));
            root.first = Math.max(0, Math.min(root.first, root.results.length - root.rows));
        });
    }

    // Kısayol, logo ya da büyüteç: yalnızca odaktaki ekranın araması açılır
    function onFocusedScreen() {
        const focused = Hyprland.focusedMonitor;
        return !focused || !root.screen || focused.name === root.screen.name;
    }
    Connections {
        target: Ui
        function onSearchRequested() {
            if (root.onFocusedScreen() && !(root.open && root.clipboard))
                root.toggle();
            else if (root.onFocusedScreen())
                root.show("search");
            else
                root.close();
        }
        function onClipboardRequested() {
            if (!root.onFocusedScreen())
                root.close();
            else if (root.open && root.clipboard)
                root.close();
            else
                root.show("clipboard");
        }
    }

    onResultsChanged: {
        if (currentIndex >= results.length || results[currentIndex]?.enabled === false) {
            currentIndex = 0;
            first = 0;
        }
        first = Math.max(0, Math.min(first, results.length - rows));
    }

    visible: open
    color: "transparent"
    anchors.top: true
    margins.top: Math.round((screen?.height ?? 1080) * 0.2)
    implicitWidth: Metrics.searchWidth
    implicitHeight: Metrics.searchWindowHeight
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "desk-search"
    // Açıkken klavye hep aramada
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    mask: Region {
        item: panel
    }

    BackgroundEffect.blurRegion: Region {
        item: panel
        radius: Metrics.searchRadius
    }

    HyprlandFocusGrab {
        active: root.open
        windows: [root]
        onCleared: root.close()
    }

    onOpenChanged: {
        if (open)
            Qt.callLater(() => input.forceActiveFocus());
    }

    Rectangle {
        id: panel

        width: parent.width
        height: column.implicitHeight
        radius: Metrics.searchRadius
        color: Colors.glass
        border.width: 1
        border.color: Colors.panelBorder

        ColumnLayout {
            id: column

            width: parent.width
            spacing: 0

            // ---------- Arama kutusu ----------
            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: Metrics.searchBoxHeight
                Layout.leftMargin: 18
                Layout.rightMargin: 18
                spacing: 12

                Icon {
                    name: root.clipboard ? "clipboard-list" : "search"
                    size: 20
                    strokeWidth: 2.2
                    color: Colors.textMuted
                }

                TextInput {
                    id: input

                    Layout.fillWidth: true
                    color: Colors.text
                    selectionColor: Colors.accent
                    selectedTextColor: Colors.accentForeground
                    font.family: Typography.family
                    font.pixelSize: 20
                    clip: true
                    focus: true

                    onTextChanged: {
                        Launcher.query = text;
                        root.currentIndex = 0;
                        root.first = 0;
                    }

                    Keys.onPressed: event => {
                        const ctrl = (event.modifiers & Qt.ControlModifier) !== 0;
                        switch (event.key) {
                        case Qt.Key_Escape:
                            if (text !== "")
                                text = "";
                            else
                                root.close();
                            break;
                        case Qt.Key_Down:
                        case Qt.Key_Tab:
                            root.move(1);
                            break;
                        case Qt.Key_Up:
                        case Qt.Key_Backtab:
                            root.move(-1);
                            break;
                        case Qt.Key_Return:
                        case Qt.Key_Enter:
                            root.run(root.currentIndex, ctrl);
                            break;
                        case Qt.Key_PageDown:
                            root.select(Math.min(root.results.length - 1, root.currentIndex + root.rows));
                            break;
                        case Qt.Key_PageUp:
                            root.select(Math.max(0, root.currentIndex - root.rows));
                            break;
                        // Pano hâlinde Delete seçili kaydı siler (imleç yazının sonundayken; yoksa harf siler)
                        case Qt.Key_Delete:
                            if (!root.clipboard || cursorPosition < text.length)
                                return;
                            root.removeSelected();
                            break;
                        default:
                            return;
                        }
                        event.accepted = true;
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: input.text === ""
                        text: root.clipboard ? "Pano geçmişinde ara" : "Ara: uygulama, ayar, hesap ya da / ile dosya"
                        color: Colors.textFaint
                        font: input.font
                    }
                }

                // Dosya ararken küçük bir "aranıyor" işareti; pano hâlinde kayıt sayısı
                Text {
                    visible: text !== ""
                    text: root.clipboard ? (root.results[0]?.kind === "clip" ? `${root.results.length} kayıt` : "") : Launcher.fileMode && Launcher.searchingFiles ? "aranıyor…" : ""
                    color: Colors.textFaint
                    font.family: Typography.family
                    font.pixelSize: Typography.small
                }
            }

            // Kutu ile sonuçlar arası çizgi
            Rectangle {
                Layout.fillWidth: true
                visible: root.results.length > 0
                implicitHeight: 1
                color: Colors.menuSeparator
            }

            // Boşken küçük başlık (son kullanılanlar; hiç yoksa dock'taki uygulamalar)
            Text {
                Layout.leftMargin: 20
                Layout.topMargin: 8
                visible: input.text === "" && root.results.length > 0 && !root.clipboard
                text: "Önerilenler"
                color: Colors.textFaint
                font.family: Typography.family
                font.pixelSize: Typography.small
                font.weight: Font.DemiBold
            }

            // ---------- Sonuçlar ----------
            // Model sonuç sayısı: yazdıkça satırlar baştan kurulmaz, yerinde güncellenir
            ColumnLayout {
                id: resultList

                Layout.fillWidth: true
                Layout.margins: 8
                visible: root.results.length > 0
                spacing: 0

                Repeater {
                    model: root.shown.length

                    delegate: ResultRow {
                        required property int index
                        readonly property int position: root.first + index

                        Layout.fillWidth: true
                        item: root.shown[index] ?? ({})
                        selected: position === root.currentIndex
                        onMoved: point => {
                            const moved = root.lastMouse.x >= 0 && (point.x !== root.lastMouse.x || point.y !== root.lastMouse.y);
                            root.lastMouse = point;
                            if (moved && item.enabled !== false)
                                root.currentIndex = position;
                        }
                        onClicked: root.run(position, false)
                    }
                }

                WheelHandler {
                    acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                    onWheel: event => {
                        // Dokunmatik yüzeyde küçük adımlar birikir
                        wheelRest += event.angleDelta.y;
                        while (Math.abs(wheelRest) >= 120) {
                            root.scroll(wheelRest > 0 ? -1 : 1);
                            wheelRest -= wheelRest > 0 ? 120 : -120;
                        }
                    }
                    property real wheelRest: 0
                }
            }
        }

        // Kaydırma göstergesi: 8'den çok sonuç varsa sağ kenarda ince çizgi
        Rectangle {
            visible: resultList.visible && root.results.length > root.rows
            x: panel.width - 7
            y: resultList.y + resultList.height * root.first / Math.max(1, root.results.length)
            width: 3
            height: resultList.height * root.rows / Math.max(1, root.results.length)
            radius: 1.5
            color: Colors.scrollIndicator
        }
    }

    // Tek sonuç satırı: [simge] başlık / alt yazı ……… tür
    component ResultRow: Rectangle {
        id: row

        property var item
        property bool selected: false
        readonly property bool enabled_: item.enabled !== false
        // Pano resmi: küçük hâli istenir, hazır olunca görünür
        readonly property string thumb: item.entry?.image ? (Clipboard.thumbs[item.entry.id] ?? "") : ""
        onItemChanged: {
            if (item.entry?.image)
                Clipboard.requestThumb(item.entry);
        }
        readonly property color foreground: selected && enabled_ ? Colors.accentForeground : Colors.text

        signal moved(point position)   // fare satırın üstünde hareket etti (pencereye göre konum)
        signal clicked

        implicitHeight: Metrics.searchRowHeight
        radius: 10
        color: selected && enabled_ ? Colors.accent : "transparent"

        RowLayout {
            anchors {
                fill: parent
                leftMargin: 10
                rightMargin: 12
            }
            spacing: 12

            Item {
                implicitWidth: 30
                implicitHeight: 30

                IconImage {
                    anchors.centerIn: parent
                    visible: (row.item.image ?? "") !== ""
                    source: row.item.image ?? ""
                    implicitSize: 30
                }
                // Panodaki resmin küçük hâli
                ClippingRectangle {
                    anchors.fill: parent
                    visible: row.thumb !== ""
                    radius: 6
                    color: Colors.circleOff

                    Image {
                        anchors.fill: parent
                        source: row.thumb !== "" ? "file://" + row.thumb : ""
                        sourceSize: Qt.size(60, 60)
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                    }
                }
                Rectangle {
                    anchors.fill: parent
                    visible: (row.item.image ?? "") === "" && row.thumb === ""
                    radius: 8
                    color: row.selected && row.enabled_ ? Qt.rgba(row.foreground.r, row.foreground.g, row.foreground.b, 0.14) : Colors.circleOff

                    Icon {
                        anchors.centerIn: parent
                        name: row.item.icon ?? ""
                        size: 17
                        strokeWidth: 2.2
                        color: row.selected && row.enabled_ ? row.foreground : Colors.circleOffIcon
                    }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1

                Text {
                    Layout.fillWidth: true
                    text: row.item.title ?? ""
                    color: row.foreground
                    font.family: Typography.family
                    font.pixelSize: row.item.kind === "calc" ? 19 : Typography.body + 1
                    font.weight: Font.DemiBold
                    // Dosya adında sonu (uzantı) önemli; panodaki yazıda başı
                    elide: row.item.kind === "clip" ? Text.ElideRight : Text.ElideMiddle
                }
                Text {
                    Layout.fillWidth: true
                    visible: text !== ""
                    // Kısayol ipucu yalnızca seçili satırda
                    text: [row.item.subtitle ?? "", row.selected ? (row.item.hint ?? "") : ""].filter(t => t !== "").join(" · ")
                    color: row.selected && row.enabled_ ? Qt.rgba(row.foreground.r, row.foreground.g, row.foreground.b, 0.75) : Colors.textMuted
                    font.family: Typography.family
                    font.pixelSize: Typography.small
                    elide: Text.ElideMiddle
                }
            }

            Text {
                visible: text !== ""
                text: row.item.tag ?? ""
                color: row.selected && row.enabled_ ? Qt.rgba(row.foreground.r, row.foreground.g, row.foreground.b, 0.7) : Colors.textFaint
                font.family: Typography.family
                font.pixelSize: Typography.small
            }
        }

        MouseArea {
            anchors.fill: parent
            enabled: row.enabled_
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onPositionChanged: mouse => row.moved(mapToItem(null, mouse.x, mouse.y))
            onClicked: row.clicked()
        }
    }
}
