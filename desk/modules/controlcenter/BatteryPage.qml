import QtQuick
import QtQuick.Layouts
import Quickshell.Services.UPower
import qs.theme
import qs.services

// Pil menüsü: doluluk, kalan süre, çekilen güç, pil sağlığı ve güç modu
ColumnLayout {
    id: root

    required property var center

    spacing: 8

    // 12.43 → "12,4"
    function number(value) {
        return Number(value).toLocaleString(Qt.locale("tr_TR"), "f", 1);
    }

    PageHeader {
        Layout.fillWidth: true
        title: "Pil"
        showBack: root.center.canGoBack
        onBack: root.center.back()
    }

    // Doluluk ve durum
    Tile {
        Layout.fillWidth: true
        visible: BatteryStatus.present

        RowLayout {
            width: parent.width
            spacing: 14

            Text {
                text: "%" + Math.round(BatteryStatus.level * 100)
                color: Colors.text
                font.family: Typography.family
                font.pixelSize: 30
                font.weight: Font.DemiBold
                font.features: {
                    "tnum": 1
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4

                // Doluluk çubuğu
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 8
                    radius: 4
                    color: Colors.sliderTrack

                    Rectangle {
                        width: parent.width * Math.max(0, Math.min(1, BatteryStatus.level))
                        height: parent.height
                        radius: 4
                        color: BatteryStatus.charging ? Colors.accent : BatteryStatus.level < 0.15 ? Colors.microphone : Colors.sliderFill
                    }
                }
                Text {
                    Layout.fillWidth: true
                    text: BatteryStatus.stateText
                    color: Colors.textMuted
                    font.family: Typography.family
                    font.pixelSize: Typography.small
                    elide: Text.ElideRight
                }
            }
        }
    }

    Text {
        Layout.fillWidth: true
        Layout.margins: 8
        visible: !BatteryStatus.present
        text: "Pil bulunamadı; bilgisayar prizden çalışıyor."
        color: Colors.textMuted
        font.family: Typography.family
        font.pixelSize: Typography.small
    }

    // Ayrıntılar
    Tile {
        Layout.fillWidth: true
        visible: BatteryStatus.present

        ColumnLayout {
            width: parent.width
            spacing: 8

            InfoRow {
                Layout.fillWidth: true
                label: BatteryStatus.charging ? "Şarj gücü" : "Çekilen güç"
                value: BatteryStatus.powerDraw > 0 ? root.number(BatteryStatus.powerDraw) + " W" : ""
            }
            InfoRow {
                Layout.fillWidth: true
                visible: BatteryStatus.health > 0
                label: "Pil sağlığı"
                value: "%" + Math.round(BatteryStatus.health)
            }
            InfoRow {
                Layout.fillWidth: true
                visible: BatteryStatus.capacity > 0
                label: "Dolu kapasite"
                value: root.number(BatteryStatus.capacity) + " Wh"
            }
        }
    }

    SectionTitle {
        text: "Güç modu"
    }

    Repeater {
        model: PowerMode.modes

        delegate: ListRow {
            required property var modelData
            readonly property bool unavailable: modelData.profile === PowerProfile.Performance && !PowerMode.hasPerformance

            Layout.fillWidth: true
            icon: modelData.icon
            title: modelData.name
            subtitle: unavailable ? "Bu bilgisayarda yok" : modelData.detail
            active: PowerMode.profile === modelData.profile
            checked: PowerMode.profile === modelData.profile
            selectable: !unavailable
            onClicked: PowerMode.set(modelData.profile)
        }
    }
}
