import QtQuick
import QtQuick.Layouts
import Quickshell.Bluetooth
import qs.theme
import qs.components
import qs.services

// Bir Bluetooth cihazının ayrıntıları: bağlan/kes, unut, ad değiştir, güvenilir, engelle, MAC adresi.
ColumnLayout {
    id: root

    required property var center
    required property var device

    property bool confirmForget: false
    property bool renaming: false

    spacing: 8

    Timer {
        id: forgetTimer
        interval: 3000
        onTriggered: root.confirmForget = false
    }

    PageHeader {
        Layout.fillWidth: true
        title: root.device?.name ?? "Bluetooth"
        showBack: root.center.canGoBack
        onBack: root.center.back()
    }

    Text {
        Layout.fillWidth: true
        Layout.margins: 8
        visible: root.device === null
        text: "Bu cihaz artık listede değil."
        color: Colors.textMuted
        font.family: Typography.family
        font.pixelSize: Typography.small
    }

    ColumnLayout {
        Layout.fillWidth: true
        visible: root.device !== null
        spacing: 10

        // Durum
        Tile {
            Layout.fillWidth: true

            RowLayout {
                width: parent.width
                spacing: 12

                Rectangle {
                    implicitWidth: 40
                    implicitHeight: 40
                    radius: 20
                    color: root.device?.connected ? Colors.accent : Colors.circleOff

                    Icon {
                        anchors.centerIn: parent
                        name: BluetoothStatus.iconFor(root.device)
                        size: 19
                        strokeWidth: 2.2
                        color: root.device?.connected ? Colors.accentForeground : Colors.circleOffIcon
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 1

                    Text {
                        Layout.fillWidth: true
                        text: {
                            const d = root.device;
                            if (!d)
                                return "";
                            if (d.state === BluetoothDeviceState.Connecting)
                                return "Bağlanıyor…";
                            if (d.state === BluetoothDeviceState.Disconnecting)
                                return "Bağlantı kesiliyor…";
                            return d.connected ? "Bağlı" : "Bağlı değil";
                        }
                        color: Colors.text
                        font.family: Typography.family
                        font.pixelSize: Typography.body
                        font.weight: Font.DemiBold
                    }
                    Text {
                        Layout.fillWidth: true
                        text: BluetoothStatus.typeName(root.device) + (root.device?.batteryAvailable ? ` · pil %${Math.round(root.device.battery * 100)}` : "")
                        color: Colors.textMuted
                        font.family: Typography.family
                        font.pixelSize: Typography.small
                    }
                }
            }
        }

        // Eylemler
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            TextButton {
                Layout.fillWidth: true
                text: root.device?.connected ? "Bağlantıyı kes" : "Bağlan"
                accent: !(root.device?.connected ?? false)
                onClicked: root.device.connected ? root.device.disconnect() : root.device.connect()
            }
            TextButton {
                Layout.fillWidth: true
                text: root.confirmForget ? "Emin misin? Tekrar bas" : "Bu cihazı unut"
                danger: true
                onClicked: {
                    if (!root.confirmForget) {
                        root.confirmForget = true;
                        forgetTimer.restart();
                        return;
                    }
                    root.device.forget();
                    root.center.back();
                }
            }
        }

        // Ad: bu bilgisayarda görünen ad (cihazın kendisi değişmez)
        Tile {
            Layout.fillWidth: true

            RowLayout {
                width: parent.width
                spacing: 8

                InfoRow {
                    Layout.fillWidth: true
                    visible: !root.renaming
                    label: "Ad"
                    value: root.device?.name ?? ""
                }
                TextField {
                    id: nameField
                    Layout.fillWidth: true
                    visible: root.renaming
                    placeholder: root.device?.deviceName ?? ""
                    onAccepted: {
                        root.device.name = text.trim() === "" ? root.device.deviceName : text.trim();
                        root.renaming = false;
                    }
                    onCanceled: root.renaming = false
                }
                TextButton {
                    text: root.renaming ? "Kaydet" : "Değiştir"
                    onClicked: {
                        if (root.renaming) {
                            nameField.accepted();
                        } else {
                            nameField.text = root.device?.name ?? "";
                            root.renaming = true;
                            nameField.focusInput();
                        }
                    }
                }
            }
        }

        SettingRow {
            Layout.fillWidth: true
            Layout.leftMargin: 4
            Layout.rightMargin: 4
            title: "Güvenilir"
            subtitle: "Açılınca sormadan bağlanabilir"
            checked: root.device?.trusted ?? false
            onToggled: root.device.trusted = !root.device.trusted
        }

        SettingRow {
            Layout.fillWidth: true
            Layout.leftMargin: 4
            Layout.rightMargin: 4
            title: "Engelle"
            subtitle: "Bu cihazın bağlanmasına hiç izin verme"
            checked: root.device?.blocked ?? false
            onToggled: root.device.blocked = !root.device.blocked
        }

        SectionTitle {
            text: "Ayrıntılar"
        }

        Tile {
            Layout.fillWidth: true

            ColumnLayout {
                width: parent.width
                spacing: 8

                InfoRow {
                    Layout.fillWidth: true
                    label: "MAC adresi"
                    value: root.device?.address ?? ""
                    copyable: true
                }
                InfoRow {
                    Layout.fillWidth: true
                    label: "Tür"
                    value: BluetoothStatus.typeName(root.device)
                }
                InfoRow {
                    Layout.fillWidth: true
                    label: "Eşleşme"
                    value: root.device?.paired || root.device?.bonded ? "Eşleşmiş" : "Eşleşmemiş"
                }
                InfoRow {
                    Layout.fillWidth: true
                    visible: root.device?.batteryAvailable ?? false
                    label: "Pil"
                    value: "%" + Math.round((root.device?.battery ?? 0) * 100)
                }
            }
        }
    }
}
