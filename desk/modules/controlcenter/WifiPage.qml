import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Networking
import qs.theme
import qs.components
import qs.services

// Wi-Fi sayfası: aç/kapa, çevredeki ağlar, şifre girişi.
// Kayıtlı ve bağlı ağlarda ⓘ düğmesi ayrıntıları açar (IP, MAC, unut …).
ColumnLayout {
    id: root

    required property var center

    // Bağlanılmaya çalışılan ağ, ona şifre soruluyor mu, son hata
    property var current: null
    property bool asking: false
    property string error: ""

    // Şifre yazılırken liste yeniden sıralanmasın (kutu kaybolur); o sırada liste dondurulur
    property var shownNetworks: []
    Binding on shownNetworks {
        when: !root.asking
        value: NetworkStatus.networks
        restoreMode: Binding.RestoreNone
    }

    spacing: 8

    // Sayfa açıkken ağlar taranır. Tarama, panel ekrana geldikten sonra başlar:
    // tarama sonuçları peş peşe gelir, açılış animasyonunu aksatmasın.
    Timer {
        running: true
        interval: 150
        onTriggered: NetworkStatus.setScanning(true)
    }
    Component.onDestruction: NetworkStatus.setScanning(false)

    function select(network) {
        error = "";
        if (network.connected)
            return;
        current = network;
        if (NetworkStatus.connect(network)) {
            asking = false;
            return;
        }
        if (!NetworkStatus.supportsPassword(network)) {
            asking = false;
            error = "Bu ağ türü (kurumsal giriş) burada desteklenmiyor.";
            return;
        }
        asking = true;
    }

    // Kayıtlı ağın şifresi değişmişse ya da yanlış şifre girildiyse şifre sorulur
    Connections {
        target: root.current
        ignoreUnknownSignals: true

        function onConnectionFailed(reason) {
            if (reason === ConnectionFailReason.NoSecrets && NetworkStatus.supportsPassword(root.current)) {
                root.error = root.asking ? "Şifre yanlış olabilir, tekrar dene." : "";
                root.asking = true;
            } else {
                root.error = "Bağlanılamadı.";
            }
        }
        function onConnectedChanged() {
            if (root.current?.connected) {
                root.asking = false;
                root.current = null;
                root.error = "";
            }
        }
    }

    PageHeader {
        Layout.fillWidth: true
        title: "Wi-Fi"
        showBack: root.center.canGoBack
        showSwitch: true
        checked: NetworkStatus.wifiEnabled
        onBack: root.center.back()
        onToggled: NetworkStatus.setWifiEnabled(!NetworkStatus.wifiEnabled)
    }

    Text {
        Layout.fillWidth: true
        Layout.margins: 8
        visible: !NetworkStatus.wifiEnabled || root.shownNetworks.length === 0
        text: !NetworkStatus.wifiEnabled ? "Wi-Fi kapalı." : "Ağlar aranıyor…"
        color: Colors.textMuted
        font.family: Typography.family
        font.pixelSize: Typography.small
    }

    Text {
        Layout.fillWidth: true
        Layout.leftMargin: 8
        visible: root.error !== "" && !root.asking
        text: root.error
        color: Colors.warning
        font.family: Typography.family
        font.pixelSize: Typography.small
        wrapMode: Text.WordWrap
    }

    // Ağ listesi. ListView yalnızca görünen satırları kurar (yurt gibi çok ağlı yerlerde önemli).
    // ScriptModel: liste değişince satırlar baştan kurulmaz; yalnızca eklenir, çıkarılır
    // ya da yer değiştirir, yer değiştiren satır da kısa bir kaymayla yerine gider.
    ListView {
        id: list

        Layout.fillWidth: true
        Layout.preferredHeight: Math.min(contentHeight, 380)
        visible: count > 0
        clip: true
        spacing: 2
        boundsBehavior: Flickable.StopAtBounds

        model: ScriptModel {
            values: root.shownNetworks
        }

        move: Transition {
            NumberAnimation {
                property: "y"
                duration: Metrics.durationNormal
                easing.type: Easing.OutCubic
            }
        }
        displaced: Transition {
            NumberAnimation {
                property: "y"
                duration: Metrics.durationNormal
                easing.type: Easing.OutCubic
            }
        }

        delegate: ColumnLayout {
            id: entry

            required property var modelData
            readonly property bool asking: root.asking && root.current === modelData

            width: ListView.view.width
            spacing: 4

            ListRow {
                Layout.fillWidth: true
                title: entry.modelData.name
                subtitle: entry.modelData.connected ? "Bağlı" : entry.modelData.stateChanging ? "Bağlanıyor…" : entry.modelData.known ? "Kayıtlı" : ""
                active: entry.modelData.connected
                trailingIcon: NetworkStatus.isSecured(entry.modelData) ? "lock" : ""
                showInfo: entry.modelData.known || entry.modelData.connected
                iconComponent: Component {
                    WifiIcon {
                        size: 15
                        strength: entry.modelData.signalStrength
                        color: entry.modelData.connected ? Colors.accentForeground : Colors.circleOffIcon
                    }
                }
                onClicked: root.select(entry.modelData)
                onInfoClicked: root.center.show("wifi-network", entry.modelData)
            }

            // Şifre kutusu: yalnızca seçilen ağın altında ve yalnızca gerektiğinde kurulur
            Loader {
                Layout.fillWidth: true
                Layout.leftMargin: 8
                Layout.rightMargin: 8
                Layout.bottomMargin: 6
                active: entry.asking
                visible: active

                sourceComponent: PasswordField {
                    error: root.error
                    onSubmitted: password => {
                        root.error = "";
                        entry.modelData.connectWithPsk(password);
                    }
                    onCanceled: {
                        root.asking = false;
                        root.current = null;
                        root.error = "";
                    }
                }
            }
        }
    }

    // Listede görünmeyen ağlar için
    RowLayout {
        Layout.fillWidth: true
        Layout.topMargin: 2
        visible: NetworkStatus.wifiEnabled
        spacing: 8

        TextButton {
            Layout.fillWidth: true
            text: "Gizli ağa bağlan…"
            onClicked: root.center.show("wifi-hidden")
        }
        TextButton {
            Layout.fillWidth: true
            text: "Kayıtlı ağlar"
            onClicked: root.center.show("wifi-saved")
        }
    }
}
