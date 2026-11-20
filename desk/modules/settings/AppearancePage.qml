import QtQuick
import QtQuick.Layouts
import qs.theme
import qs.components
import qs.services
import qs.settings

// Görünüm: vurgu rengi, saydamlık, hareket, duvar kâğıdı
SettingsPage {
    id: page

    title: "Görünüm"

    SettingsSection {
        title: "Vurgu rengi"
        footer: "Düğmeler, anahtarlar ve seçimler bu renkte. kitty ve Dolphin de aynı renge geçer."

        OptionRow {
            id: accentRow

            readonly property string chosen: Settings.s.appearance.accent

            title: Settings.s.appearance.accent === "" ? "Duvar kâğıdından" : (Colors.accentPresets.find(p => p.color === accentRow.chosen)?.name ?? "Özel renk")
            implicitHeight: 64

            Row {
                spacing: 8

                // Otomatik: duvar kâğıdının rengi, üstünde küçük resim simgesi
                Swatch {
                    swatchColor: Colors.wallpaperAccent
                    selected: accentRow.chosen === ""
                    tip: "Duvar kâğıdından"
                    auto: true
                    onClicked: Settings.set("appearance.accent", "")
                }
                Repeater {
                    model: Colors.accentPresets
                    Swatch {
                        required property var modelData
                        swatchColor: Colors.readableAccent(modelData.color)
                        selected: accentRow.chosen === modelData.color
                        tip: modelData.name
                        onClicked: Settings.set("appearance.accent", modelData.color)
                    }
                }
            }
        }
    }

    SettingsSection {
        title: "Saydamlık ve hareket"

        SwitchRow {
            title: "Saydamlığı azalt"
            subtitle: "Menüler, dock ve bar daha koyu ve örtücü olur; arkadaki pencere daha az görünür"
            setting: "appearance.reduceTransparency"
        }
        SwitchRow {
            title: "Hareketi azalt"
            subtitle: "Pencere animasyonları kapanır, desk'teki geçişler kısalır"
            setting: "appearance.reduceMotion"
        }
    }

    SettingsSection {
        title: "Duvar kâğıdı"

        ButtonRow {
            title: Wallpaper.basename(Wallpaper.current) || "Duvar kâğıdı"
            subtitle: "Renkler duvar kâğıdından gelir (Super+W)"
            buttonText: "Değiştir…"
            buttonIcon: "image"
            onClicked: Ui.wallpaperRequested()
        }
    }

    // Renk yuvarlağı; seçiliyse çevresinde halka
    component Swatch: Item {
        id: swatch

        property color swatchColor
        property bool selected: false
        property bool auto: false
        property string tip
        signal clicked

        width: 26
        height: 26

        Rectangle {
            anchors.fill: parent
            radius: width / 2
            color: "transparent"
            border.width: 2
            border.color: swatch.selected ? Colors.selectionRing : "transparent"
        }
        Rectangle {
            anchors.centerIn: parent
            width: 18
            height: 18
            radius: 9
            color: swatch.swatchColor
            scale: swatchMouse.containsMouse && !swatch.selected ? 1.1 : 1

            Behavior on scale {
                NumberAnimation { duration: Metrics.durationFast }
            }

            Icon {
                visible: swatch.auto
                anchors.centerIn: parent
                name: "image"
                size: 11
                strokeWidth: 2.4
                color: Colors.accentForegroundFor(swatch.swatchColor)
            }
        }
        MouseArea {
            id: swatchMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: swatch.clicked()
        }
        ToolTipText {
            visible: swatchMouse.containsMouse
            text: swatch.tip
        }
    }

    // Küçük ad etiketi (yuvarlağın altında)
    component ToolTipText: Rectangle {
        property alias text: tipLabel.text

        anchors.horizontalCenter: parent.horizontalCenter
        y: parent.height + 4
        z: 10
        width: tipLabel.implicitWidth + 12
        height: tipLabel.implicitHeight + 6
        radius: 6
        color: Colors.tooltip
        border.width: 1
        border.color: Colors.panelBorder

        Text {
            id: tipLabel
            anchors.centerIn: parent
            color: Colors.text
            font.family: Typography.family
            font.pixelSize: Typography.small
        }
    }
}
