import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import qs.theme
import qs.components
import qs.services

// Adanın bildirim hâli: [simge] başlık · uygulama · zaman / metin ……… [Yanıtla] [Sustur]
// Tıklayınca uygulamanın kendi eylemi (yoksa penceresi) açılır. Yanıtla: metin adanın içinde yazılır.
// Ada küçülürken son bildirim görünmeye devam eder (içerik solarak gider).
Item {
    id: root

    required property var island      // Island.qml: replying

    // Gösterilen bildirim; ada kapanırken boşalmasın diye son bildirim saklanır
    property var entry: null
    readonly property var current: Notifications.current
    onCurrentChanged: {
        if (current) {
            entry = current;
            replyField.text = "";
        }
    }

    readonly property var live: entry?.live ?? null
    // Canlı bildirim güncellenirse (uygulama yerine yenisini gönderdi) yazılar da değişir
    readonly property string title: (live ? live.summary : entry?.summary) || (entry?.appName ?? "")
    readonly property string body: Notifications.plain(live ? live.body : (entry?.body ?? ""))
    readonly property bool canReply: Notifications.canReply(entry)
    readonly property var appActions: Notifications.actionsOf(entry)

    width: Metrics.islandNoticeWidth
    height: Metrics.islandNoticeHeight + (island.replying ? Metrics.islandReplyHeight : 0)

    // Bildirime tıklama (düğmeler kendi tıklamalarını alır)
    MouseArea {
        anchors.fill: parent
        enabled: !root.island.replying
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            if (root.entry)
                Notifications.activate(root.entry);
        }
    }

    HoverHandler {
        id: hover
    }

    ColumnLayout {
        anchors {
            fill: parent
            leftMargin: 18
            rightMargin: 18
            topMargin: 14
            bottomMargin: 14
        }
        spacing: 10

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: Metrics.islandNoticeHeight - 28
            spacing: 14

            // Simge: kişinin resmi (varsa, köşede uygulama simgesi), uygulama simgesi ya da çizgi simge
            Item {
                Layout.alignment: Qt.AlignVCenter
                implicitWidth: 44
                implicitHeight: 44

                ClippingRectangle {
                    anchors.fill: parent
                    visible: (root.live?.image ?? "") !== ""
                    radius: 22
                    color: Colors.islandButton

                    Image {
                        anchors.fill: parent
                        source: root.live?.image ?? ""
                        sourceSize: Qt.size(88, 88)
                        fillMode: Image.PreserveAspectCrop
                    }
                }
                IconImage {
                    anchors.fill: parent
                    visible: (root.live?.image ?? "") === "" && (root.entry?.icon ?? "") !== ""
                    source: root.entry?.icon ?? ""
                    implicitSize: 44
                }
                Rectangle {
                    anchors.fill: parent
                    visible: (root.live?.image ?? "") === "" && (root.entry?.icon ?? "") === ""
                    radius: 12
                    color: Colors.islandButton

                    Icon {
                        anchors.centerIn: parent
                        name: root.entry?.glyph || "bell"
                        size: 22
                        strokeWidth: 2.2
                        color: root.entry?.urgency === 2 ? Colors.microphone : Colors.islandProgress
                    }
                }
                // Kişi resmi varsa uygulamanın simgesi köşede
                IconImage {
                    visible: (root.live?.image ?? "") !== "" && (root.entry?.icon ?? "") !== ""
                    anchors {
                        right: parent.right
                        bottom: parent.bottom
                        rightMargin: -3
                        bottomMargin: -3
                    }
                    source: root.entry?.icon ?? ""
                    implicitSize: 18
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                spacing: 2

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Text {
                        Layout.maximumWidth: 260
                        text: root.title
                        color: Colors.islandProgress
                        font.family: Typography.family
                        font.pixelSize: 15
                        font.weight: Font.DemiBold
                        elide: Text.ElideRight
                        textFormat: Text.PlainText
                    }
                    Text {
                        Layout.fillWidth: true
                        text: [root.entry?.appName ?? "", root.entry ? Notifications.timeText(root.entry.time) : ""].filter(t => t !== "" && t !== root.title).join(" · ")
                        color: Colors.islandFaint
                        font.family: Typography.family
                        font.pixelSize: 12
                        elide: Text.ElideRight
                    }
                }
                Text {
                    Layout.fillWidth: true
                    visible: text !== ""
                    text: root.body
                    color: Colors.islandText
                    font.family: Typography.family
                    font.pixelSize: 13
                    wrapMode: Text.Wrap
                    maximumLineCount: 2
                    elide: Text.ElideRight
                    textFormat: Text.PlainText
                }
            }

            // Düğmeler: Yanıtla (destekleniyorsa) ya da uygulamanın ilk düğmesi, sonra Sustur
            ColumnLayout {
                Layout.alignment: Qt.AlignVCenter
                spacing: 6

                NoticeButton {
                    visible: root.canReply
                    text: "Yanıtla"
                    onClicked: {
                        root.island.replying = true;
                        replyField.forceActiveFocus();
                    }
                }
                NoticeButton {
                    visible: !root.canReply && root.appActions.length > 0
                    text: root.appActions.length > 0 ? root.appActions[0].text : ""
                    onClicked: Notifications.invoke(root.entry, root.appActions[0])
                }
                // Kendi uyarılarımız (pil) ve acil bildirimler susturulmaz
                NoticeButton {
                    visible: root.live !== null && (root.entry?.appName ?? "") !== "" && root.entry?.urgency !== 2
                    text: "Sustur"
                    onClicked: Notifications.muteApp(root.entry.appName)
                }
            }
        }

        // Yanıt satırı
        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: Metrics.islandReplyHeight - 10
            visible: root.island.replying
            spacing: 8

            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: height / 2
                color: Colors.islandButton

                TextInput {
                    id: replyField
                    anchors {
                        fill: parent
                        leftMargin: 14
                        rightMargin: 14
                    }
                    verticalAlignment: TextInput.AlignVCenter
                    color: Colors.islandProgress
                    selectionColor: Colors.accent
                    selectedTextColor: Colors.accentForeground
                    font.family: Typography.family
                    font.pixelSize: 13
                    clip: true

                    Keys.onReturnPressed: root.send()
                    Keys.onEnterPressed: root.send()
                    Keys.onEscapePressed: root.island.replying = false

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: replyField.text === ""
                        text: root.live?.inlineReplyPlaceholder || "Yanıt yaz…"
                        color: Colors.islandFaint
                        font: replyField.font
                    }
                }
            }
            NoticeButton {
                Layout.fillHeight: true
                text: "Gönder"
                strong: true
                onClicked: root.send()
            }
        }
    }

    // Kapat: yalnızca adadan kalkar, merkezde kalır (üstüne gelince görünür)
    Rectangle {
        anchors {
            top: parent.top
            right: parent.right
            topMargin: 8
            rightMargin: 12
        }
        visible: hover.hovered && !root.island.replying
        width: 20
        height: 20
        radius: 10
        color: closeMouse.containsMouse ? Colors.islandButton : "transparent"

        Icon {
            anchors.centerIn: parent
            name: "x"
            size: 12
            strokeWidth: 2.4
            color: Colors.islandMuted
        }
        MouseArea {
            id: closeMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: Notifications.next()
        }
    }

    function send() {
        if (replyField.text.trim() === "")
            return;
        Notifications.reply(entry, replyField.text);
        island.replying = false;
    }

    // Adadaki küçük yuvarlak düğme
    component NoticeButton: Rectangle {
        id: button

        property string text
        property bool strong: false
        signal clicked

        implicitWidth: Math.max(78, label.implicitWidth + 24)
        implicitHeight: 28
        radius: height / 2
        color: strong ? (buttonMouse.containsMouse ? Colors.accentHover : Colors.accent) : buttonMouse.containsMouse ? Colors.islandButtonActive : Colors.islandButton

        Text {
            id: label
            anchors.centerIn: parent
            text: button.text
            color: button.strong ? Colors.accentForeground : Colors.islandProgress
            font.family: Typography.family
            font.pixelSize: 12
            font.weight: Font.DemiBold
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
