import QtQuick
import QtQuick.Layouts
import qs.theme
import qs.components
import qs.services

// Eşleşme yardımcısının sorusu (BluetoothStatus.request; scripts/bt_agent.py):
// kod onayı, PIN ya da kod yazma, eşleşme ve bağlantı izni, cihazda yazılacak kod.
// Bluetooth sayfasının üstünde durur; soru gelince kontrol merkezi bu sayfada açılır.
Tile {
    id: root

    required property var request

    readonly property string kind: request?.kind ?? ""
    readonly property var device: BluetoothStatus.deviceFor(request)
    readonly property bool needsInput: kind === "pin" || kind === "passkey"
    readonly property bool showOnly: kind.startsWith("show-")
    readonly property string code: request?.code ?? ""

    readonly property string message: {
        switch (kind) {
        case "confirm":
            return "Eşleştirilsin mi? Cihazda bir kod görünüyorsa bununla aynı olmalı.";
        case "authorize":
            return "Bu bilgisayarla eşleşmek istiyor.";
        case "service": {
            const what = BluetoothStatus.serviceName(request?.uuid);
            return what ? `Bağlanmak istiyor (${what}).` : "Bağlanmak istiyor.";
        }
        case "pin":
            return "Cihazın PIN'ini yaz. Kılavuzunda yazar; çoğunda 0000 ya da 1234.";
        case "passkey":
            return "Cihazın ekranında görünen 6 haneli kodu yaz.";
        case "show-pin":
        case "show-passkey":
            return "Bu kodu cihazda (klavyedeyse klavyede) yazıp Enter'a bas.";
        }
        return "";
    }

    // "033412" → "033 412"
    function grouped(text) {
        return text.length === 6 ? text.slice(0, 3) + " " + text.slice(3) : text;
    }

    function accept() {
        if (showOnly)
            BluetoothStatus.answer(request, true);
        else if (needsInput)
            BluetoothStatus.answer(request, field.text.trim() !== "", field.text.trim());
        else
            BluetoothStatus.answer(request, true);
    }

    function reject() {
        BluetoothStatus.answer(request, false);
    }

    // Yeni soru gelince yazı kutusu boşalsın ve yazmaya hazır olsun
    onRequestChanged: {
        field.text = "";
        if (needsInput)
            Qt.callLater(field.focusInput);
    }
    Component.onCompleted: {
        if (needsInput)
            Qt.callLater(field.focusInput);
    }

    ColumnLayout {
        width: parent.width
        spacing: 10

        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            Rectangle {
                Layout.alignment: Qt.AlignTop
                implicitWidth: 40
                implicitHeight: 40
                radius: 20
                color: Colors.accent

                Icon {
                    anchors.centerIn: parent
                    name: BluetoothStatus.iconFor(root.device)
                    size: 19
                    strokeWidth: 2.2
                    color: Colors.accentForeground
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2

                Text {
                    Layout.fillWidth: true
                    text: root.request?.name || "Bluetooth cihazı"
                    color: Colors.text
                    font.family: Typography.family
                    font.pixelSize: Typography.body
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                }
                Text {
                    Layout.fillWidth: true
                    text: root.message
                    color: Colors.textMuted
                    font.family: Typography.family
                    font.pixelSize: Typography.small
                    wrapMode: Text.Wrap
                }
            }
        }

        // Onaylanacak ya da cihazda yazılacak kod
        Text {
            Layout.fillWidth: true
            visible: root.code !== ""
            text: root.grouped(root.code)
            horizontalAlignment: Text.AlignHCenter
            color: Colors.text
            font.family: Typography.mono
            font.pixelSize: 26
            font.weight: Font.DemiBold
            font.letterSpacing: 2
        }
        Text {
            Layout.fillWidth: true
            visible: root.kind === "show-passkey" && (root.request?.entered ?? 0) > 0
            text: `${root.request?.entered ?? 0} / 6 hane yazıldı`
            horizontalAlignment: Text.AlignHCenter
            color: Colors.textFaint
            font.family: Typography.family
            font.pixelSize: Typography.small
        }

        TextField {
            id: field
            Layout.fillWidth: true
            visible: root.needsInput
            placeholder: root.kind === "pin" ? "PIN" : "6 haneli kod"
            onAccepted: root.accept()
            onCanceled: root.reject()
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            TextButton {
                Layout.fillWidth: true
                visible: !root.showOnly
                text: root.kind === "authorize" || root.kind === "service" ? "Reddet" : "Vazgeç"
                onClicked: root.reject()
            }
            TextButton {
                Layout.fillWidth: true
                accent: true
                text: root.showOnly ? "Tamam" : root.kind === "authorize" || root.kind === "service" ? "İzin ver" : "Eşleştir"
                enabled_: !root.needsInput || field.text.trim() !== ""
                onClicked: root.accept()
            }
        }
    }
}
