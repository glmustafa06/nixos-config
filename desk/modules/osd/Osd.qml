import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.theme
import qs.components
import qs.services

// Ses ve parlaklık göstergesi: tuşa basınca barın altında, sağda kısa süre görünür
// (macOS Sonoma'daki gibi). Tıklamaları engellemez.
PanelWindow {
    id: root

    required property var modelData
    screen: modelData

    property string kind: "volume"   // "volume" ya da "brightness"
    property bool shown: false

    // Yalnızca odaktaki ekranda göster; kontrol merkezi açıkken gösterme (sürgüler orada),
    // bildirim merkezi açıkken de (aynı köşede üst üste binerdi)
    function show(newKind) {
        if (Ui.controlCenterOpen || Ui.notificationCenterOpen)
            return;
        const focused = Hyprland.focusedMonitor;
        if (focused && modelData && focused.name !== modelData.name)
            return;
        kind = newKind;
        shown = true;
        hideTimer.restart();
    }

    visible: shown
    color: "transparent"

    anchors {
        top: true
        right: true
    }
    margins.top: Metrics.popoutTop
    margins.right: Metrics.popoutRight
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "desk-osd"

    // Boş bölge: fare göstergenin içinden geçer
    mask: Region {}

    implicitWidth: Metrics.osdWidth
    implicitHeight: panel.implicitHeight

    BackgroundEffect.blurRegion: Region {
        item: panel
        radius: panel.radius
    }

    Timer {
        id: hideTimer
        interval: 1500
        onTriggered: root.shown = false
    }

    Connections {
        target: Ui
        function onOsdRequested(kind) {
            root.show(kind);
        }
    }

    // Ses değişince (tuş, bardaki tekerlek ya da başka bir program) göster.
    // Açılışta ve çıkış aygıtı değişirken düzey kendiliğinden değişir; o anlarda gösterme.
    property bool ready: false
    Timer {
        running: true
        interval: 2000
        onTriggered: root.ready = true
    }
    Timer {
        id: sinkGuard
        interval: 600
    }
    Connections {
        target: AudioStatus
        function onSinkChanged() {
            sinkGuard.restart();
        }
        function onVolumeChanged() {
            if (root.ready && !sinkGuard.running)
                root.show("volume");
        }
        function onMutedChanged() {
            if (root.ready && !sinkGuard.running)
                root.show("volume");
        }
    }

    Rectangle {
        id: panel

        width: parent.width
        height: parent.height
        implicitHeight: content.implicitHeight + 30
        radius: 18
        color: Colors.panel
        border.width: 1
        border.color: Colors.panelBorder

        ColumnLayout {
            id: content

            anchors {
                left: parent.left
                right: parent.right
                top: parent.top
                leftMargin: 16
                rightMargin: 16
                topMargin: 14
            }
            spacing: 10

            RowLayout {
                Layout.fillWidth: true
                spacing: 5

                Text {
                    Layout.fillWidth: true
                    text: root.kind === "brightness" ? "Ekran" : "Ses"
                    color: Colors.text
                    font.family: Typography.family
                    font.pixelSize: 13
                    font.weight: Font.DemiBold
                }

                // Ses: hangi aygıttan çıktığı
                Icon {
                    visible: root.kind === "volume"
                    name: /head/i.test(AudioStatus.outputName) ? "headphones" : "speaker"
                    size: 13
                    color: Colors.textMuted
                }
                Text {
                    visible: root.kind === "volume"
                    Layout.maximumWidth: 220
                    text: AudioStatus.muted ? "Sessiz" : AudioStatus.outputName
                    color: Colors.textMuted
                    font.family: Typography.family
                    font.pixelSize: Typography.small
                    elide: Text.ElideRight
                }
            }

            Slider {
                Layout.fillWidth: true
                icon: root.kind === "brightness" ? "sun-medium" : AudioStatus.icon
                value: root.kind === "brightness" ? Brightness.level : AudioStatus.muted ? 0 : AudioStatus.volume
            }
        }
    }
}
