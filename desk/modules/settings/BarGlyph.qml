import QtQuick
import qs.theme
import qs.components
import qs.services

// Bardaki bir öğenin simgesi (Ayarlar → Üst bar'daki önizleme ve liste için)
//   id: tray, keyboard, bluetooth, sound, battery, wifi, search, controlcenter, clock
Item {
    id: root

    property string itemId
    property color color: Colors.text
    property string clockText: "18:40"

    implicitWidth: loader.item?.implicitWidth ?? 16
    implicitHeight: 18

    Loader {
        id: loader
        anchors.verticalCenter: parent.verticalCenter
        sourceComponent: {
            switch (root.itemId) {
            case "keyboard":
                return keyboard;
            case "battery":
                return battery;
            case "controlcenter":
                return controlCenter;
            case "clock":
                return clock;
            case "tray":
                return tray;
            default:
                return icon;
            }
        }
    }

    Component {
        id: icon
        Icon {
            name: ({
                    bluetooth: "bluetooth",
                    sound: "volume-2",
                    wifi: "wifi",
                    search: "search"
                })[root.itemId] ?? "app-window"
            size: Metrics.barIconSize
            strokeWidth: Metrics.barIconStroke
            color: root.color
        }
    }
    Component {
        id: keyboard
        Text {
            text: KeyboardLayout.code
            color: root.color
            font.family: Typography.family
            font.pixelSize: Typography.small
            font.weight: Font.DemiBold
            font.letterSpacing: 0.4
        }
    }
    Component {
        id: battery
        BatteryIcon {
            level: BatteryStatus.present ? BatteryStatus.level : 0.8
            color: root.color
        }
    }
    Component {
        id: controlCenter
        ControlCenterIcon {
            color: root.color
        }
    }
    Component {
        id: clock
        Text {
            text: root.clockText
            color: root.color
            font.family: Typography.family
            font.pixelSize: Typography.bar
            font.weight: Font.Medium
        }
    }
    // Tepsi: iki küçük uygulama simgesi yerine iki yuvarlak
    Component {
        id: tray
        Row {
            spacing: 5
            Repeater {
                model: 2
                Rectangle {
                    width: 13
                    height: 13
                    radius: 4
                    color: "transparent"
                    border.width: 1.6
                    border.color: root.color
                }
            }
        }
    }
}
