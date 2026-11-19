import QtQuick
import QtQuick.Layouts
import qs.theme
import qs.services

// Adını yayınlamayan (gizli) bir ağa bağlan: ad ve şifre yazılır.
ColumnLayout {
    id: root

    required property var center

    property bool busy: false
    property string message: ""
    property bool failed: false

    spacing: 10

    Component.onCompleted: nameField.focusInput()

    function connect() {
        const ssid = nameField.text.trim();
        if (ssid === "" || busy)
            return;
        const command = ["nmcli", "device", "wifi", "connect", ssid];
        if (passwordField.text !== "")
            command.push("password", passwordField.text);
        command.push("hidden", "yes");

        busy = true;
        message = "Bağlanılıyor…";
        failed = false;
        Commands.run(command, (code, out, err) => {
            root.busy = false;
            if (code === 0) {
                root.message = "Bağlandı.";
                root.center.back();
            } else {
                root.failed = true;
                root.message = "Bağlanılamadı: " + (err.trim() || out.trim()).replace(/^Error:\s*/, "");
            }
        });
    }

    PageHeader {
        Layout.fillWidth: true
        title: "Gizli ağa bağlan"
        showBack: root.center.canGoBack
        onBack: root.center.back()
    }

    Text {
        Layout.fillWidth: true
        Layout.leftMargin: 4
        text: "Ağın adını harfi harfine yaz. Şifresiz ağlarda şifre boş kalabilir."
        color: Colors.textMuted
        font.family: Typography.family
        font.pixelSize: Typography.small
        wrapMode: Text.WordWrap
    }

    TextField {
        id: nameField
        Layout.fillWidth: true
        placeholder: "Ağ adı"
        onAccepted: passwordField.focusInput()
        onCanceled: root.center.back()
    }

    TextField {
        id: passwordField
        Layout.fillWidth: true
        placeholder: "Şifre"
        password: true
        onAccepted: root.connect()
        onCanceled: root.center.back()
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: 8

        Text {
            Layout.fillWidth: true
            text: root.message
            color: root.failed ? Colors.warning : Colors.textMuted
            font.family: Typography.family
            font.pixelSize: Typography.small
            wrapMode: Text.WordWrap
        }
        TextButton {
            text: "Bağlan"
            accent: true
            enabled_: !root.busy && nameField.text.trim() !== ""
            onClicked: root.connect()
        }
    }
}
