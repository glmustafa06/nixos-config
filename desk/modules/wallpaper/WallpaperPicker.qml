import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Widgets
import qs.theme
import qs.components
import qs.services

// Duvar kâğıdı seçici (Super+W): ekranın ortasında küçük resimlerden bir ızgara.
// Tıklayınca (ya da oklarla gelip Enter) duvar kâğıdı yumuşakça değişir; seçici açık kalır,
// başka resim denenebilir. Esc ya da dışarı tıklamak kapatır.
PanelWindow {
    id: root

    required property var modelData
    screen: modelData

    property bool open: false

    function toggle() {
        if (open)
            open = false;
        else
            show();
    }
    function show() {
        Wallpaper.refresh();
        open = true;
    }
    function choose(path) {
        Wallpaper.set(path);
    }

    // Kısayol yalnızca odaktaki ekranda açar
    Connections {
        target: Ui
        function onWallpaperRequested() {
            const focused = Hyprland.focusedMonitor;
            if (!focused || !root.screen || focused.name === root.screen.name)
                root.toggle();
            else
                root.open = false;
        }
    }

    // Liste gelince seçim şu anki duvar kâğıdına gider
    Connections {
        target: Wallpaper
        function onImagesChanged() {
            grid.currentIndex = Math.max(0, Wallpaper.images.indexOf(Wallpaper.current));
            grid.positionViewAtIndex(grid.currentIndex, GridView.Contain);
        }
    }

    visible: open
    color: "transparent"
    implicitWidth: Metrics.wallpaperPickerWidth
    // Az resim varsa kısa; çoksa en çok wallpaperPickerHeight, gerisi kayar
    readonly property real cellWidth: Math.floor((Metrics.wallpaperPickerWidth - 36) / Metrics.wallpaperColumns)
    readonly property real cellHeight: Math.round(cellWidth * 9 / 16)
    readonly property int rows: Math.max(1, Math.ceil(Wallpaper.images.length / Metrics.wallpaperColumns))
    implicitHeight: Math.min(Metrics.wallpaperPickerHeight, 16 + 26 + 12 + rows * cellHeight + 18)
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "desk-wallpaper-picker"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    mask: Region {
        item: panel
    }
    BackgroundEffect.blurRegion: Region {
        item: panel
        radius: panel.radius
    }

    HyprlandFocusGrab {
        active: root.open
        windows: [root]
        onCleared: root.open = false
    }

    onOpenChanged: {
        if (open)
            Qt.callLater(() => grid.forceActiveFocus());
    }

    Rectangle {
        id: panel

        anchors.fill: parent
        radius: 24
        color: Colors.glass
        border.width: 1
        border.color: Colors.panelBorder

        Keys.onEscapePressed: root.open = false

        ColumnLayout {
            anchors {
                fill: parent
                margins: 18
                topMargin: 16
            }
            spacing: 12

            // Başlık: Duvar kâğıdı · klasör ……… Klasörü aç
            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                Text {
                    text: "Duvar kâğıdı"
                    color: Colors.text
                    font.family: Typography.family
                    font.pixelSize: 16
                    font.weight: Font.DemiBold
                }
                Text {
                    Layout.fillWidth: true
                    text: Wallpaper.directory.replace(Quickshell.env("HOME"), "~")
                    color: Colors.textFaint
                    font.family: Typography.family
                    font.pixelSize: 12
                    elide: Text.ElideMiddle
                }
                Text {
                    visible: Wallpaper.coloring
                    text: "Renkler güncelleniyor…"
                    color: Colors.textFaint
                    font.family: Typography.family
                    font.pixelSize: 12
                }
                LinkButton {
                    text: "Klasörü aç"
                    onClicked: {
                        root.open = false;
                        Wallpaper.openFolder();
                    }
                }
            }

            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true

                GridView {
                    id: grid

                    anchors.fill: parent
                    visible: Wallpaper.images.length > 0
                    clip: true
                    focus: true
                    cellWidth: root.cellWidth
                    cellHeight: root.cellHeight
                    boundsBehavior: Flickable.StopAtBounds
                    keyNavigationWraps: false
                    highlightFollowsCurrentItem: false
                    model: Wallpaper.images

                    Keys.onReturnPressed: root.choose(Wallpaper.images[currentIndex])
                    Keys.onEnterPressed: root.choose(Wallpaper.images[currentIndex])
                    Keys.onEscapePressed: root.open = false

                    delegate: Item {
                        id: cell

                        required property string modelData
                        required property int index
                        readonly property bool isCurrent: modelData === Wallpaper.current
                        readonly property bool selected: GridView.isCurrentItem

                        width: grid.cellWidth
                        height: grid.cellHeight

                        ClippingRectangle {
                            id: thumb

                            anchors {
                                fill: parent
                                margins: 6
                            }
                            radius: 12
                            color: Colors.tile

                            Image {
                                anchors.fill: parent
                                source: Wallpaper.fileUrl(cell.modelData)
                                fillMode: Image.PreserveAspectCrop
                                sourceSize: Qt.size(thumb.width * 2, thumb.height * 2)
                                asynchronous: true
                                smooth: true
                            }
                        }
                        // Çerçeve: şu anki duvar kâğıdı vurgu renginde, klavyeyle seçilen ve üstüne gelinen açık
                        Rectangle {
                            anchors.fill: thumb
                            anchors.margins: -3
                            radius: thumb.radius + 3
                            color: "transparent"
                            border.width: cell.isCurrent || cell.selected || mouse.containsMouse ? 3 : 0
                            border.color: cell.isCurrent ? Colors.accent : Colors.selectionRing
                        }
                        Rectangle {
                            visible: cell.isCurrent
                            anchors {
                                right: thumb.right
                                bottom: thumb.bottom
                                margins: 8
                            }
                            width: 22
                            height: 22
                            radius: 11
                            color: Colors.accent

                            Icon {
                                anchors.centerIn: parent
                                name: "check"
                                size: 13
                                strokeWidth: 3
                                color: Colors.accentForeground
                            }
                        }
                        MouseArea {
                            id: mouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                grid.currentIndex = cell.index;
                                root.choose(cell.modelData);
                            }
                        }
                    }
                }

                // Boş ya da yükleniyor
                ColumnLayout {
                    anchors.centerIn: parent
                    visible: Wallpaper.images.length === 0
                    spacing: 8

                    Icon {
                        Layout.alignment: Qt.AlignHCenter
                        name: "image"
                        size: 26
                        strokeWidth: 2
                        color: Colors.textFaint
                    }
                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: Wallpaper.loading ? "Yükleniyor…" : "Bu klasörde resim yok"
                        color: Colors.textMuted
                        font.family: Typography.family
                        font.pixelSize: 13
                    }
                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        visible: !Wallpaper.loading
                        text: "Klasöre JPG ya da PNG koy, sonra seçiciyi yeniden aç."
                        color: Colors.textFaint
                        font.family: Typography.family
                        font.pixelSize: 12
                    }
                }
            }
        }
    }

    component LinkButton: Rectangle {
        id: link

        property string text
        signal clicked

        implicitWidth: label.implicitWidth + 18
        implicitHeight: 26
        radius: 13
        color: linkMouse.containsMouse ? Colors.buttonHover : Colors.button

        Text {
            id: label
            anchors.centerIn: parent
            text: link.text
            color: Colors.text
            font.family: Typography.family
            font.pixelSize: 12
        }
        MouseArea {
            id: linkMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: link.clicked()
        }
    }
}
