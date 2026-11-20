import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import qs.theme
import qs.components
import qs.services
import qs.settings

// Çekimden sonra sağ altta küçük önizleme (macOS'taki gibi). Dosya zaten kaydedildi, görüntü panoda.
//   tıkla        görüntü Satty'de düzenlenir (Enter kaydedip kopyalar, Esc vazgeçer); kayıt oynatılır
//   üstüne gel   sağ altta Düzenle, Klasörde göster, Sil (çöpe); sağ üstte ×
//   sürükle      dosyayı bir uygulamaya bırak (sohbete, tarayıcıya…)
// Birkaç saniye sonra kendiliğinden kayar gider (süre Ayarlar'da); fare üstündeyken bekler.
PanelWindow {
    id: root

    required property var modelData
    screen: modelData

    // Çekim bu ekranda mı yapıldı
    readonly property bool mine: Screenshot.screenName === "" || Screenshot.screenName === (modelData?.name ?? "")
    property bool shown: false
    property string file: ""
    property string thumb: ""
    property bool video: false
    property int duration: 0

    // Ayarlar → Ekran görüntüsü → Önizleme (0: hiç gösterilmez; dosya yine kaydedilir, panoya kopyalanır)
    readonly property int seconds: Settings.s.screenshot.previewSeconds

    function show() {
        if (seconds <= 0)
            return;
        file = Screenshot.lastFile;
        thumb = Screenshot.lastThumb;
        video = Screenshot.lastIsVideo;
        duration = Screenshot.lastDuration;
        shown = true;
        hideTimer.restart();
    }
    function hide() {
        shown = false;
    }

    // Yeni çekim başlarken anında kalkar (kayarak değil): yeni görüntüye girmesin
    property bool instant: false

    Connections {
        target: Screenshot
        function onPreviewSerialChanged() {
            if (root.mine)
                root.show();
            else
                root.hide();
        }
        function onPreviewHideRequested() {
            root.instant = true;
            root.hide();
            Qt.callLater(() => root.instant = false);
        }
    }

    Timer {
        id: hideTimer
        interval: Math.max(1, root.seconds) * 1000
        onTriggered: {
            if (hover.hovered || dragging)
                restart();
            else
                root.hide();
        }
    }

    function url(path) {
        return path === "" ? "" : "file://" + path.split("/").map(encodeURIComponent).join("/");
    }

    // Küçük resmin ölçüsü: en çok 240 × 150, oranı korunur
    readonly property real aspect: image.implicitHeight > 0 ? image.implicitWidth / image.implicitHeight : 16 / 9
    readonly property real cardWidth: aspect >= 240 / 150 ? 240 : Math.round(150 * aspect)
    readonly property real cardHeight: Math.round(cardWidth / aspect)

    visible: shown || card.x < width
    anchors {
        bottom: true
        right: true
    }
    margins {
        bottom: 6
        right: 6
    }
    implicitWidth: 240 + 40
    implicitHeight: 150 + 40
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "desk-shot-preview"

    mask: Region {
        item: card
    }

    property bool dragging: false

    Item {
        id: card

        width: root.cardWidth
        height: root.cardHeight
        y: root.height - height - 20
        // Sağdan kayarak gelir, sağa kayarak gider
        x: root.shown ? root.width - width - 20 : root.width + 30

        Behavior on x {
            enabled: !root.instant
            NumberAnimation {
                duration: Metrics.durationNormal + 60
                easing.type: Easing.OutCubic
            }
        }

        HoverHandler {
            id: hover
        }

        RectangularShadow {
            anchors.fill: parent
            radius: 12
            blur: 22
            spread: -2
            offset.y: 4
            color: Colors.dockShadow
        }

        ClippingRectangle {
            anchors.fill: parent
            radius: 12
            color: Colors.tooltip
            border.width: 1
            border.color: Colors.panelBorder

            Image {
                id: image
                anchors.fill: parent
                source: root.url(root.thumb)
                cache: false
                asynchronous: true
                fillMode: Image.PreserveAspectCrop
                sourceSize: Qt.size(480, 300)
            }

            // Kayıt: ortada oynat simgesi, solda süre
            Rectangle {
                visible: root.video
                anchors.centerIn: parent
                width: 40
                height: 40
                radius: 20
                color: Colors.previewBadge

                Icon {
                    anchors.centerIn: parent
                    anchors.horizontalCenterOffset: 1
                    name: "play"
                    size: 18
                    strokeWidth: 2.2
                    color: Colors.text
                    fill: Colors.text
                }
            }

            // Üstüne gelince altta karartma ve düğmeler
            Rectangle {
                anchors {
                    left: parent.left
                    right: parent.right
                    bottom: parent.bottom
                }
                height: 44
                opacity: hover.hovered || root.video ? 1 : 0
                gradient: Gradient {
                    GradientStop {
                        position: 0
                        color: "transparent"
                    }
                    GradientStop {
                        position: 1
                        color: Colors.previewShade
                    }
                }

                Behavior on opacity {
                    NumberAnimation { duration: Metrics.durationFast }
                }

                Text {
                    visible: root.video
                    anchors {
                        left: parent.left
                        leftMargin: 10
                        bottom: parent.bottom
                        bottomMargin: 8
                    }
                    text: Media.formatTime(root.duration)
                    color: Colors.text
                    font.family: Typography.family
                    font.pixelSize: Typography.small
                    font.weight: Font.DemiBold
                    font.features: {
                        "tnum": 1
                    }
                }
            }

            // Sürükleyip bırakmak için: dosyanın adresi
            Item {
                id: dragSource
                anchors.fill: parent
                Drag.dragType: Drag.Automatic
                Drag.supportedActions: Qt.CopyAction
                Drag.mimeData: ({
                        "text/uri-list": root.url(root.file)
                    })
                Drag.imageSource: root.url(root.thumb)
                Drag.onDragFinished: root.dragging = false
            }

            MouseArea {
                id: area

                property point pressPoint

                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onPressed: mouse => pressPoint = Qt.point(mouse.x, mouse.y)
                onPositionChanged: mouse => {
                    if (!root.dragging && pressed && Math.hypot(mouse.x - pressPoint.x, mouse.y - pressPoint.y) > 10) {
                        root.dragging = true;
                        dragSource.Drag.active = true;
                    }
                }
                onClicked: {
                    if (root.dragging)
                        return;
                    Screenshot.edit(root.file);
                    root.hide();
                }
            }

            // Düğmeler (sağ altta) ve kapat (sağ üstte)
            Row {
                anchors {
                    right: parent.right
                    rightMargin: 6
                    bottom: parent.bottom
                    bottomMargin: 6
                }
                spacing: 4
                opacity: hover.hovered ? 1 : 0
                visible: opacity > 0

                Behavior on opacity {
                    NumberAnimation { duration: Metrics.durationFast }
                }

                PreviewButton {
                    visible: !root.video
                    icon: "pencil"
                    onClicked: {
                        Screenshot.edit(root.file);
                        root.hide();
                    }
                }
                PreviewButton {
                    icon: "folder"
                    onClicked: {
                        Screenshot.showInFolder(root.file);
                        root.hide();
                    }
                }
                PreviewButton {
                    icon: "trash-2"
                    onClicked: {
                        Screenshot.remove(root.file);
                        root.hide();
                    }
                }
            }
            PreviewButton {
                anchors {
                    right: parent.right
                    rightMargin: 6
                    top: parent.top
                    topMargin: 6
                }
                opacity: hover.hovered ? 1 : 0
                visible: opacity > 0
                icon: "x"
                onClicked: root.hide()

                Behavior on opacity {
                    NumberAnimation { duration: Metrics.durationFast }
                }
            }
        }
    }

    // Küçük yuvarlak düğme
    component PreviewButton: Rectangle {
        id: button

        property string icon
        signal clicked

        width: 26
        height: 26
        radius: 13
        color: buttonMouse.containsMouse ? Colors.previewButtonHover : Colors.previewBadge

        Icon {
            anchors.centerIn: parent
            name: button.icon
            size: 14
            strokeWidth: 2.3
            color: Colors.text
        }
        MouseArea {
            id: buttonMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: button.clicked()
        }
    }
}
