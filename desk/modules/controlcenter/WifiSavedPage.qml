import QtQuick
import QtQuick.Layouts
import qs.theme
import qs.services

// Kayıtlı Wi-Fi ağları (menzilde olmayanlar dahil). Buradan unutulabilir.
ColumnLayout {
    id: root

    required property var center

    // [{ name, uuid }]
    property var saved: []
    property bool loading: true
    property string confirming: ""   // unutulmak üzere olan ağın uuid'i

    spacing: 8

    Component.onCompleted: load()

    function load() {
        Commands.run(["nmcli", "-t", "-f", "NAME,UUID,TYPE", "connection", "show"], (code, out) => {
            const list = [];
            for (const line of out.split("\n")) {
                const [name, uuid, type] = Commands.splitTerse(line);
                if (type === "802-11-wireless")
                    list.push({
                        name: name,
                        uuid: uuid
                    });
            }
            root.saved = list.sort((a, b) => a.name.localeCompare(b.name, "tr"));
            root.loading = false;
        });
    }

    function forget(entry) {
        if (confirming !== entry.uuid) {
            confirming = entry.uuid;
            confirmTimer.restart();
            return;
        }
        confirming = "";
        Commands.run(["nmcli", "connection", "delete", "uuid", entry.uuid], () => root.load());
    }

    Timer {
        id: confirmTimer
        interval: 3000
        onTriggered: root.confirming = ""
    }

    PageHeader {
        Layout.fillWidth: true
        title: "Kayıtlı ağlar"
        showBack: root.center.canGoBack
        onBack: root.center.back()
    }

    Text {
        Layout.fillWidth: true
        Layout.margins: 8
        visible: root.loading || root.saved.length === 0
        text: root.loading ? "Yükleniyor…" : "Kayıtlı ağ yok."
        color: Colors.textMuted
        font.family: Typography.family
        font.pixelSize: Typography.small
    }

    Flickable {
        Layout.fillWidth: true
        Layout.preferredHeight: Math.min(contentHeight, 420)
        visible: root.saved.length > 0
        contentHeight: list.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        ColumnLayout {
            id: list
            width: parent.width
            spacing: 2

            Repeater {
                model: root.saved

                delegate: RowLayout {
                    id: entry

                    required property var modelData

                    Layout.fillWidth: true
                    spacing: 8

                    ListRow {
                        Layout.fillWidth: true
                        icon: "wifi"
                        title: entry.modelData.name
                        active: entry.modelData.name === NetworkStatus.ssid
                        subtitle: active ? "Bağlı" : ""
                        selectable: false
                        opacity: 1
                    }
                    TextButton {
                        text: root.confirming === entry.modelData.uuid ? "Emin misin?" : "Unut"
                        danger: true
                        onClicked: root.forget(entry.modelData)
                    }
                }
            }
        }
    }
}
