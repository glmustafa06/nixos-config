import QtQuick
import QtQuick.Layouts
import Quickshell.Services.UPower
import qs.theme
import qs.components
import qs.services

// Kontrol merkezinin ana sayfası (tasarım resmi 3'teki düzen)
ColumnLayout {
    id: root

    required property var center   // ControlCenter: sayfa değiştirmek ve kapatmak için

    readonly property real half: (width - spacing) / 2

    spacing: 10

    // --- Mikrofonu kullanan uygulama
    RowLayout {
        visible: AudioStatus.micInUse
        Layout.leftMargin: 6
        Layout.topMargin: 2
        spacing: 8

        Rectangle {
            implicitWidth: 7
            implicitHeight: 7
            radius: 3.5
            color: Colors.microphone
        }
        Text {
            text: "Mikrofon kullanılıyor" + (AudioStatus.micApps.length > 0 ? " ·" : "")
            color: Colors.footerText
            font.family: Typography.family
            font.pixelSize: Typography.small
        }
        Text {
            Layout.maximumWidth: 200
            text: AudioStatus.micApps.join(", ")
            color: Colors.text
            font.family: Typography.family
            font.pixelSize: Typography.small
            font.weight: Font.DemiBold
            elide: Text.ElideRight
        }
    }

    // --- Üst kısım: bağlantılar solda; rahatsız etme, gece ışığı, pano sağda
    RowLayout {
        Layout.fillWidth: true
        spacing: 10

        Tile {
            id: connections
            Layout.preferredWidth: root.half

            ColumnLayout {
                width: parent.width
                spacing: 12

                ToggleRow {
                    Layout.fillWidth: true
                    icon: NetworkStatus.wifiEnabled ? "wifi" : "wifi-off"
                    on: NetworkStatus.wifiEnabled
                    title: "Wi-Fi"
                    subtitle: NetworkStatus.summary
                    onToggled: NetworkStatus.setWifiEnabled(!NetworkStatus.wifiEnabled)
                    onOpened: root.center.show("wifi")
                }
                ToggleRow {
                    Layout.fillWidth: true
                    icon: BluetoothStatus.enabled ? "bluetooth" : "bluetooth-off"
                    on: BluetoothStatus.enabled
                    title: "Bluetooth"
                    subtitle: BluetoothStatus.summary
                    onToggled: BluetoothStatus.setEnabled(!BluetoothStatus.enabled)
                    onOpened: root.center.show("bluetooth")
                }
                ToggleRow {
                    Layout.fillWidth: true
                    icon: PowerMode.modes.find(m => m.profile === PowerMode.profile)?.icon ?? "zap"
                    on: PowerMode.profile !== PowerProfile.Balanced
                    title: "Güç modu"
                    subtitle: PowerMode.name
                    onToggled: root.center.show("battery")
                    onOpened: root.center.show("battery")
                }
            }
        }

        ColumnLayout {
            Layout.preferredWidth: root.half
            Layout.preferredHeight: connections.implicitHeight
            spacing: 10

            Tile {
                Layout.fillWidth: true
                Layout.fillHeight: true

                ToggleRow {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width
                    icon: "moon"
                    on: QuickSettings.doNotDisturb
                    title: "Rahatsız etme"
                    subtitle: QuickSettings.doNotDisturb ? "Açık" : "Kapalı"
                    onToggled: QuickSettings.setDoNotDisturb(!QuickSettings.doNotDisturb)
                    onOpened: QuickSettings.setDoNotDisturb(!QuickSettings.doNotDisturb)
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                SmallTile {
                    icon: "sun-medium"
                    label: "Gece ışığı"
                    on: QuickSettings.nightLight
                    onClicked: QuickSettings.setNightLight(!QuickSettings.nightLight)
                }
                SmallTile {
                    icon: "clipboard-list"
                    label: "Pano"
                    onClicked: {
                        root.center.close();
                        Ui.clipboardRequested();
                    }
                }
            }
        }
    }

    // --- Ekran parlaklığı
    Tile {
        Layout.fillWidth: true
        visible: Brightness.available
        padding: 14

        ColumnLayout {
            width: parent.width
            spacing: 10

            Text {
                text: "Ekran"
                color: Colors.text
                font.family: Typography.family
                font.pixelSize: 13
                font.weight: Font.DemiBold
            }
            Slider {
                Layout.fillWidth: true
                icon: "sun-medium"
                value: Brightness.level
                onMoved: value => Brightness.set(value)
            }
        }
    }

    // --- Ses: başlıkta çıkış aygıtı (tıklayınca aygıt listesi)
    Tile {
        Layout.fillWidth: true
        padding: 14

        ColumnLayout {
            width: parent.width
            spacing: 10

            RowLayout {
                Layout.fillWidth: true
                spacing: 6

                Text {
                    Layout.fillWidth: true
                    text: "Ses"
                    color: Colors.text
                    font.family: Typography.family
                    font.pixelSize: 13
                    font.weight: Font.DemiBold
                }

                Item {
                    implicitWidth: outputRow.implicitWidth
                    implicitHeight: outputRow.implicitHeight

                    RowLayout {
                        id: outputRow
                        spacing: 4

                        Icon {
                            name: /head/i.test(AudioStatus.outputName) ? "headphones" : "speaker"
                            size: 13
                            color: outputMouse.containsMouse ? Colors.text : Colors.textMuted
                        }
                        Text {
                            Layout.maximumWidth: 210
                            text: AudioStatus.outputName
                            color: outputMouse.containsMouse ? Colors.text : Colors.textMuted
                            font.family: Typography.family
                            font.pixelSize: Typography.small
                            elide: Text.ElideRight
                        }
                        Icon {
                            name: "chevron-right"
                            size: 13
                            color: outputMouse.containsMouse ? Colors.text : Colors.textMuted
                        }
                    }

                    MouseArea {
                        id: outputMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.center.show("sound")
                    }
                }
            }

            Slider {
                Layout.fillWidth: true
                icon: AudioStatus.icon
                value: AudioStatus.muted ? 0 : AudioStatus.volume
                onMoved: value => AudioStatus.setVolume(value)
            }
        }
    }

    // --- Çalan müzik
    Tile {
        Layout.fillWidth: true
        visible: Media.active
        padding: 10

        RowLayout {
            width: parent.width
            spacing: 12

            AlbumArt {
                size: 46
                source: Media.artUrl
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1

                Text {
                    Layout.fillWidth: true
                    text: Media.title
                    color: Colors.text
                    font.family: Typography.family
                    font.pixelSize: Typography.body
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                }
                Text {
                    Layout.fillWidth: true
                    text: Media.artist
                    color: Colors.textMuted
                    font.family: Typography.family
                    font.pixelSize: Typography.small
                    elide: Text.ElideRight
                }
            }

            MediaButton {
                icon: "skip-back"
                onClicked: Media.previous()
            }
            MediaButton {
                icon: Media.playing ? "pause" : "play"
                iconSize: 18
                onClicked: Media.togglePlaying()
            }
            MediaButton {
                icon: "skip-forward"
                onClicked: Media.next()
            }
        }
    }

    // --- Alt satır: pil, ayarlar, güç
    RowLayout {
        Layout.fillWidth: true
        Layout.leftMargin: 6
        Layout.rightMargin: 2
        spacing: 8

        // Tıklayınca pil sayfası
        Text {
            Layout.fillWidth: true
            text: BatteryStatus.summary
            color: batteryMouse.containsMouse ? Colors.text : Colors.footerText
            font.family: Typography.family
            font.pixelSize: Typography.small
            elide: Text.ElideRight

            MouseArea {
                id: batteryMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.center.show("battery")
            }
        }
        // Duvar kâğıdı seçici
        CircleButton {
            icon: "image"
            size: 32
            iconSize: 16
            onClicked: {
                root.center.close();
                Ui.wallpaperRequested();
            }
        }
        CircleButton {
            icon: "power"
            size: 32
            iconSize: 16
            onClicked: root.center.show("session")
        }
    }

    // Küçük kare kutu: simge ve altında kısa yazı (gece ışığı, pano)
    component SmallTile: Tile {
        id: tile

        property string icon
        property string label
        property bool on: false

        // İki kutu eşit genişlikte
        Layout.fillWidth: true
        Layout.preferredWidth: 50
        Layout.preferredHeight: 60
        padding: 0
        clickable: true
        highlighted: on

        ColumnLayout {
            anchors.centerIn: parent
            spacing: 5

            Icon {
                Layout.alignment: Qt.AlignHCenter
                name: tile.icon
                size: 19
                strokeWidth: 2.2
                color: tile.on ? Colors.accentForeground : Colors.text
            }
            Text {
                Layout.alignment: Qt.AlignHCenter
                text: tile.label
                color: tile.on ? Colors.accentForeground : Colors.text
                font.family: Typography.family
                font.pixelSize: Typography.small
                font.weight: Font.DemiBold
            }
        }
    }

    // Oynatma düğmesi (dolgulu simge, üstüne gelince hafif zemin)
    component MediaButton: Rectangle {
        id: button

        property string icon
        property real iconSize: 16
        signal clicked

        implicitWidth: 32
        implicitHeight: 32
        radius: 16
        color: buttonMouse.containsMouse ? Colors.hover : "transparent"

        Icon {
            anchors.centerIn: parent
            name: button.icon
            size: button.iconSize
            strokeWidth: 2
            color: Colors.text
            fill: Colors.text
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
