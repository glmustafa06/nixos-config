import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Bluetooth
import qs.theme
import qs.services

// Bluetooth sayfası: aç/kapa, eşleşme sorusu, bu bilgisayarın görünürlüğü, eşleşmiş cihazlar, yakındaki yeni cihazlar.
// Cihazlardaki ⓘ düğmesi ayrıntıları açar (MAC adresi, ad değiştirme, unut …).
ColumnLayout {
    id: root

    required property var center

    spacing: 8

    // Sayfa açıkken yeni cihazlar aranır (panel ekrana geldikten sonra başlar)
    Timer {
        running: true
        interval: 150
        onTriggered: BluetoothStatus.setDiscovering(true)
    }
    Component.onDestruction: BluetoothStatus.setDiscovering(false)

    // Bluetooth sonradan açılırsa aramaya başla
    Connections {
        target: BluetoothStatus
        function onEnabledChanged() {
            BluetoothStatus.setDiscovering(BluetoothStatus.enabled);
        }
    }

    function status(device) {
        if (device.pairing)
            return "Eşleştiriliyor…";
        if (device.state === BluetoothDeviceState.Connecting)
            return "Bağlanıyor…";
        if (device.state === BluetoothDeviceState.Disconnecting)
            return "Bağlantı kesiliyor…";
        if (device.connected)
            return device.batteryAvailable ? `Bağlı · pil %${Math.round(device.battery * 100)}` : "Bağlı";
        return device.paired || device.bonded ? "Bağlı değil" : "";
    }

    PageHeader {
        Layout.fillWidth: true
        title: "Bluetooth"
        showBack: root.center.canGoBack
        showSwitch: BluetoothStatus.available
        checked: BluetoothStatus.enabled
        onBack: root.center.back()
        onToggled: BluetoothStatus.setEnabled(!BluetoothStatus.enabled)
    }

    // Eşleşme sorusu: kod onayı, PIN, izin (BluetoothPrompt.qml)
    BluetoothPrompt {
        Layout.fillWidth: true
        visible: BluetoothStatus.request !== null
        request: BluetoothStatus.request
    }

    Text {
        Layout.fillWidth: true
        Layout.margins: 8
        visible: !BluetoothStatus.enabled
        text: BluetoothStatus.available ? "Bluetooth kapalı." : "Bluetooth aygıtı bulunamadı."
        color: Colors.textMuted
        font.family: Typography.family
        font.pixelSize: Typography.small
    }

    // Bu bilgisayar başka cihazlarda görünsün mü (telefondan bağlanmak için)
    SettingRow {
        Layout.fillWidth: true
        Layout.leftMargin: 8
        Layout.rightMargin: 4
        visible: BluetoothStatus.enabled
        title: "Görünür ol"
        subtitle: `Başka cihazlar bu bilgisayarı "${BluetoothStatus.adapter?.name ?? ""}" adıyla bulabilir`
        checked: BluetoothStatus.adapter?.discoverable ?? false
        onToggled: BluetoothStatus.setDiscoverable(!(BluetoothStatus.adapter?.discoverable ?? false))
    }

    Flickable {
        Layout.fillWidth: true
        Layout.preferredHeight: Math.min(contentHeight, 380)
        visible: BluetoothStatus.enabled
        contentHeight: list.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        ColumnLayout {
            id: list
            width: parent.width
            spacing: 2

            SectionTitle {
                text: "Cihazlarım"
                visible: BluetoothStatus.pairedDevices.length > 0
            }

            // ScriptModel: cihaz bulundukça liste baştan kurulmaz, yalnızca yeni satır eklenir
            Repeater {
                model: ScriptModel {
                    values: BluetoothStatus.pairedDevices
                }

                delegate: ListRow {
                    required property var modelData

                    Layout.fillWidth: true
                    icon: BluetoothStatus.iconFor(modelData)
                    title: modelData.name
                    subtitle: root.status(modelData)
                    active: modelData.connected
                    showInfo: true
                    onClicked: BluetoothStatus.activate(modelData)
                    onInfoClicked: root.center.show("bluetooth-device", modelData)
                }
            }

            SectionTitle {
                text: "Yakındaki cihazlar"
            }

            Text {
                Layout.fillWidth: true
                Layout.leftMargin: 8
                Layout.bottomMargin: 4
                visible: BluetoothStatus.nearbyDevices.length === 0
                text: "Aranıyor… Cihaz eşleştirme modunda olmalı."
                color: Colors.textFaint
                font.family: Typography.family
                font.pixelSize: Typography.small
            }

            Repeater {
                model: ScriptModel {
                    values: BluetoothStatus.nearbyDevices
                }

                delegate: ListRow {
                    required property var modelData

                    Layout.fillWidth: true
                    icon: BluetoothStatus.iconFor(modelData)
                    title: modelData.name
                    subtitle: root.status(modelData) || "Eşleştirmek için tıkla"
                    onClicked: BluetoothStatus.activate(modelData)
                }
            }
        }
    }
}
