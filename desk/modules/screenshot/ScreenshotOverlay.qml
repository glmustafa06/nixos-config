import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.theme
import qs.components
import qs.services

// Seçim ekranı (Print): ekran donar (Screenshot.frozen), üstünde seçilir. Açılır menüler de çekilebilir.
//   Alan    sürükleyerek seç; bırakınca çekilir. Boyutu yanında yazar.
//   Pencere üstüne gelinen pencere aydınlanır; tıklayınca çekilir (köşeleri yuvarlatılmış)
//   Ekran   tıkla ya da Enter
// Klavye: Boşluk alan ↔ pencere, Enter bütün ekran, Esc vazgeç.
// Altta araç çubuğu: görüntü ya da kayıt · alan, pencere, ekran · bekleme · (kayıtta) ses · kapat.
// Yalnızca seçimin başladığı ekranda açılır.
PanelWindow {
    id: root

    required property var modelData
    screen: modelData

    readonly property bool active: Screenshot.selecting && (Screenshot.screenName === "" || Screenshot.screenName === (modelData?.name ?? ""))
    readonly property string area: Screenshot.area
    readonly property bool record: Screenshot.kind === "record"

    visible: active
    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    exclusionMode: ExclusionMode.Ignore
    color: "black"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "desk-screenshot"
    WlrLayershell.keyboardFocus: active ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    // ---------- Seçim ----------
    property bool dragging: false
    property point origin
    property rect selection: Qt.rect(0, 0, 0, 0)
    property var hovered: null      // üstüne gelinen pencere: { x, y, width, height }

    onActiveChanged: {
        dragging = false;
        selection = Qt.rect(0, 0, 0, 0);
        hovered = null;
        if (active)
            Qt.callLater(() => keys.forceActiveFocus());
    }

    readonly property var monitor: Hyprland.monitorFor(modelData)
    readonly property real originX: monitor?.x ?? monitor?.lastIpcObject?.x ?? 0
    readonly property real originY: monitor?.y ?? monitor?.lastIpcObject?.y ?? 0

    // Bu ekranın etkin alanındaki pencereler, en üstteki önce: tam ekran, sonra yüzen, sonra odak sırası
    function windowsHere() {
        const workspace = monitor?.activeWorkspace ?? null;
        const list = [];
        for (const toplevel of Hyprland.toplevels.values) {
            const info = toplevel.lastIpcObject ?? {};
            if (info.hidden || !(info.pinned === true || (workspace && toplevel.workspace === workspace)))
                continue;
            const at = info.at ?? [0, 0];
            const size = info.size ?? [0, 0];
            const x = Math.max(0, at[0] - originX), y = Math.max(0, at[1] - originY);
            const right = Math.min(width, at[0] - originX + size[0]), bottom = Math.min(height, at[1] - originY + size[1]);
            if (right - x < 4 || bottom - y < 4)
                continue;
            list.push({
                x: x,
                y: y,
                width: right - x,
                height: bottom - y,
                order: [(info.fullscreen ?? 0) > 0 ? 0 : 1, info.floating ? 0 : 1, info.focusHistoryID ?? 99]
            });
        }
        return list.sort((a, b) => a.order[0] - b.order[0] || a.order[1] - b.order[1] || a.order[2] - b.order[2]);
    }

    function windowAt(x, y) {
        return windowsHere().find(w => x >= w.x && x < w.x + w.width && y >= w.y && y < w.y + w.height) ?? null;
    }

    function captureScreen() {
        Screenshot.finish({
            x: 0,
            y: 0,
            width: width,
            height: height,
            full: true
        }, false);
    }

    function setArea(value) {
        Screenshot.area = value;
        dragging = false;
        selection = Qt.rect(0, 0, 0, 0);
        hovered = value === "window" ? windowAt(mouse.mouseX, mouse.mouseY) : null;
    }

    // Aydınlık kalan yer (gerisi kararır)
    readonly property rect clear: {
        if (dragging)
            return selection;
        if (area === "window" && hovered)
            return Qt.rect(hovered.x, hovered.y, hovered.width, hovered.height);
        if (area === "screen")
            return Qt.rect(0, 0, width, height);
        return Qt.rect(0, 0, 0, 0);
    }
    readonly property bool hasClear: clear.width > 0 && clear.height > 0

    // ---------- Donmuş ekran ----------
    Image {
        anchors.fill: parent
        source: root.active && Screenshot.frozen !== "" ? "file://" + Screenshot.frozen : ""
        cache: false
        smooth: false
        fillMode: Image.Stretch
    }

    // Karartma: aydınlık yerin dört yanı. Seçim başlamadan hafif, başlayınca biraz daha koyu.
    Item {
        anchors.fill: parent
        readonly property color dim: root.hasClear ? Colors.screenshotDim : Colors.screenshotDimIdle

        Rectangle {
            x: 0
            y: 0
            width: parent.width
            height: root.hasClear ? root.clear.y : parent.height
            color: parent.dim
        }
        Rectangle {
            visible: root.hasClear
            x: 0
            y: root.clear.y + root.clear.height
            width: parent.width
            height: parent.height - y
            color: parent.dim
        }
        Rectangle {
            visible: root.hasClear
            x: 0
            y: root.clear.y
            width: root.clear.x
            height: root.clear.height
            color: parent.dim
        }
        Rectangle {
            visible: root.hasClear
            x: root.clear.x + root.clear.width
            y: root.clear.y
            width: parent.width - x
            height: root.clear.height
            color: parent.dim
        }
    }

    // Seçimin ya da pencerenin kenarı
    Rectangle {
        visible: root.hasClear && root.area !== "screen"
        x: root.clear.x - 1
        y: root.clear.y - 1
        width: root.clear.width + 2
        height: root.clear.height + 2
        color: "transparent"
        border.width: root.dragging ? 1.5 : 2
        border.color: root.dragging ? Colors.screenshotEdge : Colors.accent
        radius: root.dragging ? 0 : Screenshot.windowRadius
    }
    // Bütün ekran: içten ince vurgu çerçevesi
    Rectangle {
        visible: root.area === "screen"
        anchors.fill: parent
        color: "transparent"
        border.width: 3
        border.color: Colors.accent
    }

    // Seçimin boyutu: sağ altında küçük etiket
    Rectangle {
        visible: root.dragging && root.selection.width > 0
        x: Math.min(root.width - width - 8, root.selection.x + root.selection.width + 8)
        y: Math.min(root.height - height - 8, root.selection.y + root.selection.height + 8)
        width: sizeText.implicitWidth + 16
        height: 24
        radius: 8
        color: Colors.tooltip
        border.width: 1
        border.color: Colors.panelBorder

        Text {
            id: sizeText
            anchors.centerIn: parent
            text: `${Math.round(root.selection.width)} × ${Math.round(root.selection.height)}`
            color: Colors.text
            font.family: Typography.family
            font.pixelSize: Typography.small
            font.weight: Font.Medium
            font.features: {
                "tnum": 1
            }
        }
    }

    // ---------- Fare ----------
    MouseArea {
        id: mouse

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: root.area === "region" ? Qt.CrossCursor : Qt.PointingHandCursor

        onPressed: mouse => {
            if (root.area !== "region")
                return;
            root.origin = Qt.point(mouse.x, mouse.y);
            root.selection = Qt.rect(mouse.x, mouse.y, 0, 0);
            root.dragging = true;
        }
        onPositionChanged: mouse => {
            if (root.dragging) {
                const x = Math.max(0, Math.min(mouse.x, root.width)), y = Math.max(0, Math.min(mouse.y, root.height));
                root.selection = Qt.rect(Math.min(x, root.origin.x), Math.min(y, root.origin.y), Math.abs(x - root.origin.x), Math.abs(y - root.origin.y));
            } else if (root.area === "window") {
                root.hovered = root.windowAt(mouse.x, mouse.y);
            }
        }
        onReleased: {
            if (!root.dragging)
                return;
            root.dragging = false;
            const s = root.selection;
            // Tıklayıp bırakmak (çok küçük seçim) bir şey yapmaz
            if (s.width >= 5 && s.height >= 5)
                Screenshot.finish(s, false);
            root.selection = Qt.rect(0, 0, 0, 0);
        }
        onClicked: {
            if (root.area === "window" && root.hovered)
                Screenshot.finish(root.hovered, true);
            else if (root.area === "screen")
                root.captureScreen();
        }
    }

    // ---------- Klavye ----------
    Item {
        id: keys
        focus: true
        Keys.onPressed: event => {
            switch (event.key) {
            case Qt.Key_Escape:
                Screenshot.cancel();
                break;
            case Qt.Key_Space:
                root.setArea(root.area === "window" ? "region" : "window");
                break;
            case Qt.Key_Return:
            case Qt.Key_Enter:
                root.captureScreen();
                break;
            default:
                return;
            }
            event.accepted = true;
        }
    }

    // ---------- Araç çubuğu ----------
    ColumnLayout {
        anchors {
            horizontalCenter: parent.horizontalCenter
            bottom: parent.bottom
            bottomMargin: Metrics.dockHeight + Metrics.dockMargin + 18
        }
        spacing: 8
        // Seçerken çubuk yolu kapatmasın
        opacity: root.dragging ? 0 : 1
        visible: opacity > 0

        Behavior on opacity {
            NumberAnimation { duration: Metrics.durationFast }
        }

        // İpucu
        Rectangle {
            Layout.alignment: Qt.AlignHCenter
            implicitWidth: hint.implicitWidth + 20
            implicitHeight: 26
            radius: 13
            color: Colors.tooltip

            Text {
                id: hint
                anchors.centerIn: parent
                text: (root.record ? "Kayıt · " : "") + (root.area === "region" ? "Sürükleyerek alan seç · Boşluk: pencere · Enter: bütün ekran · Esc: vazgeç" : root.area === "window" ? "Bir pencereye tıkla · Boşluk: alan · Esc: vazgeç" : "Tıkla ya da Enter · Esc: vazgeç")
                color: Colors.textMuted
                font.family: Typography.family
                font.pixelSize: Typography.small
            }
        }

        Rectangle {
            id: bar

            Layout.alignment: Qt.AlignHCenter
            implicitWidth: tools.implicitWidth + 12
            implicitHeight: 48
            radius: 16
            color: Colors.tooltip
            border.width: 1
            border.color: Colors.panelBorder

            GlassEdge {}

            // Fare çubuğun üstündeyken seçim başlamasın
            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
            }

            RowLayout {
                id: tools

                anchors.centerIn: parent
                spacing: 2

                ToolButton {
                    icon: "camera"
                    tip: "Ekran görüntüsü"
                    selected: !root.record
                    onClicked: Screenshot.kind = "shot"
                }
                ToolButton {
                    icon: "video"
                    tip: "Ekran kaydı"
                    selected: root.record
                    onClicked: Screenshot.kind = "record"
                }
                Divider {}
                ToolButton {
                    icon: "square-dashed"
                    label: "Alan"
                    selected: root.area === "region"
                    onClicked: root.setArea("region")
                }
                ToolButton {
                    icon: "app-window"
                    label: "Pencere"
                    selected: root.area === "window"
                    onClicked: root.setArea("window")
                }
                ToolButton {
                    icon: "monitor"
                    label: "Ekran"
                    selected: root.area === "screen"
                    onClicked: root.setArea("screen")
                }
                Divider {}
                // Bekleme: Hemen → 3 sn → 10 sn
                ToolButton {
                    icon: "timer"
                    label: Screenshot.delay === 0 ? "Hemen" : `${Screenshot.delay} sn`
                    tip: "Bekleme süresi"
                    onClicked: Screenshot.delay = Screenshot.delay === 0 ? 3 : Screenshot.delay === 3 ? 10 : 0
                }
                ToolButton {
                    visible: root.record
                    icon: Screenshot.recordAudio ? "volume-2" : "volume-x"
                    label: Screenshot.recordAudio ? "Ses açık" : "Ses yok"
                    tip: "Bilgisayarın sesi kayda girsin mi"
                    selected: Screenshot.recordAudio
                    onClicked: Screenshot.setRecordAudio(!Screenshot.recordAudio)
                }
                // Bütün ekranda düğmeyle de olur
                ToolButton {
                    visible: root.area === "screen"
                    label: root.record ? "Kaydı başlat" : "Çek"
                    primary: true
                    onClicked: root.captureScreen()
                }
                Divider {}
                ToolButton {
                    icon: "x"
                    tip: "Vazgeç (Esc)"
                    onClicked: Screenshot.cancel()
                }
            }
        }
    }

    // Çubuktaki düğme: simge ve/veya yazı. selected: vurgu renginde; primary: vurgu renginde yazılı düğme
    component ToolButton: Rectangle {
        id: button

        property string icon
        property string label
        property string tip
        property bool selected: false
        property bool primary: false
        signal clicked

        readonly property bool lit: selected || primary
        readonly property color foreground: lit ? Colors.accentForeground : Colors.text

        implicitHeight: 36
        implicitWidth: content.implicitWidth + (label !== "" ? 22 : 16)
        radius: 10
        color: lit ? (buttonMouse.containsMouse ? Colors.accentHover : Colors.accent) : buttonMouse.containsMouse ? Colors.hover : "transparent"

        Behavior on color {
            ColorAnimation { duration: Metrics.durationFast }
        }

        Row {
            id: content
            anchors.centerIn: parent
            spacing: 6

            Icon {
                visible: button.icon !== ""
                anchors.verticalCenter: parent.verticalCenter
                name: button.icon
                size: 17
                strokeWidth: 2.1
                color: button.foreground
            }
            Text {
                visible: button.label !== ""
                anchors.verticalCenter: parent.verticalCenter
                text: button.label
                color: button.foreground
                font.family: Typography.family
                font.pixelSize: Typography.small + 1
                font.weight: button.lit ? Font.DemiBold : Font.Medium
            }
        }

        MouseArea {
            id: buttonMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: button.clicked()
        }

        // Yalnızca simgeli düğmenin adı üstünde
        Rectangle {
            visible: buttonMouse.containsMouse && button.tip !== ""
            anchors {
                horizontalCenter: parent.horizontalCenter
                bottom: parent.top
                bottomMargin: 12
            }
            width: tipText.implicitWidth + 16
            height: 24
            radius: 8
            color: Colors.tooltip
            border.width: 1
            border.color: Colors.panelBorder

            Text {
                id: tipText
                anchors.centerIn: parent
                text: button.tip
                color: Colors.text
                font.family: Typography.family
                font.pixelSize: Typography.small
            }
        }
    }

    component Divider: Rectangle {
        Layout.leftMargin: 4
        Layout.rightMargin: 4
        implicitWidth: 1
        implicitHeight: 22
        color: Colors.menuSeparator
    }
}
