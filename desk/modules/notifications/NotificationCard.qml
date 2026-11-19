import QtQuick
import QtQuick.Layouts
import Quickshell.Widgets
import qs.theme
import qs.components
import qs.services

// Merkezdeki tek bildirim: [simge] başlık ……… zaman / metin (en çok 3 satır)
// Üstüne gelince zamanın yerinde × çıkar (siler). Tıklayınca: clicked (merkez ne yapacağına karar verir).
Rectangle {
    id: root

    property var entry: null
    // Grubun altında başka bildirimler de var: kartın altında "+N bildirim daha"
    property int more: 0
    property bool muted: false
    // Uygulamanın simgesi yoksa zamanın önünde adı yazar ("Discord · 5 dk");
    // açık grupta ad zaten başlıkta olduğu için merkez bunu kapatır
    property bool showApp: true

    signal clicked
    signal removed
    signal unmute

    readonly property var live: entry?.live ?? null
    readonly property string title: (live ? live.summary : entry?.summary) || (entry?.appName ?? "")
    readonly property string body: Notifications.plain(live ? live.body : (entry?.body ?? ""))
    readonly property bool hasIcon: (live?.image ?? "") !== "" || (entry?.icon ?? "") !== ""
    readonly property string appName: entry?.appName ?? ""

    implicitHeight: content.implicitHeight + 22
    radius: 16
    // Üstüne gelince zemin değişmez (gri yazı açık zeminde okunmaz olurdu); × belirir
    color: Colors.tile

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }

    RowLayout {
        id: content

        anchors {
            left: parent.left
            right: parent.right
            top: parent.top
            margins: 12
            topMargin: 11
        }
        spacing: 12

        // Simge: kişi resmi, uygulama simgesi ya da çizgi simge
        Item {
            Layout.alignment: Qt.AlignTop
            implicitWidth: 34
            implicitHeight: 34

            ClippingRectangle {
                anchors.fill: parent
                visible: (root.live?.image ?? "") !== ""
                radius: 17
                color: Colors.circleOff

                Image {
                    anchors.fill: parent
                    source: root.live?.image ?? ""
                    sourceSize: Qt.size(68, 68)
                    fillMode: Image.PreserveAspectCrop
                }
            }
            IconImage {
                anchors.fill: parent
                visible: (root.live?.image ?? "") === "" && (root.entry?.icon ?? "") !== ""
                source: root.entry?.icon ?? ""
                implicitSize: 34
            }
            Rectangle {
                anchors.fill: parent
                visible: (root.live?.image ?? "") === "" && (root.entry?.icon ?? "") === ""
                radius: 9
                color: Colors.circleOff

                Icon {
                    anchors.centerIn: parent
                    name: root.entry?.glyph || "bell"
                    size: 18
                    strokeWidth: 2.2
                    color: root.entry?.urgency === 2 ? Colors.warning : Colors.circleOffIcon
                }
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Text {
                    Layout.fillWidth: true
                    text: root.title
                    color: Colors.text
                    font.family: Typography.family
                    font.pixelSize: 13
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                    textFormat: Text.PlainText
                }
                // Zaman; üstüne gelince yerini × alır (ikisi aynı yerde: satır yeniden dizilmez)
                Item {
                    implicitWidth: Math.max(timeLabel.implicitWidth, 20)
                    implicitHeight: 20

                    Text {
                        id: timeLabel
                        anchors {
                            right: parent.right
                            verticalCenter: parent.verticalCenter
                        }
                        visible: !removeButton.visible
                        text: {
                            if (!root.entry)
                                return "";
                            const time = Notifications.timeText(root.entry.time);
                            return root.showApp && !root.hasIcon && root.appName !== "" && root.appName !== root.title ? root.appName + " · " + time : time;
                        }
                        color: Colors.textFaint
                        font.family: Typography.family
                        font.pixelSize: 11
                    }
                    Rectangle {
                        id: removeButton
                        anchors {
                            right: parent.right
                            verticalCenter: parent.verticalCenter
                        }
                        visible: mouse.containsMouse || removeMouse.containsMouse
                        width: 20
                        height: 20
                        radius: 10
                        color: removeMouse.containsMouse ? Colors.circleHover : Colors.circleOff

                        Icon {
                            anchors.centerIn: parent
                            name: "x"
                            size: 11
                            strokeWidth: 2.6
                            color: Colors.text
                        }
                        MouseArea {
                            id: removeMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.removed()
                        }
                    }
                }
            }
            Text {
                Layout.fillWidth: true
                visible: text !== ""
                text: root.body
                color: Colors.textMuted
                font.family: Typography.family
                font.pixelSize: 12
                wrapMode: Text.Wrap
                maximumLineCount: 3
                elide: Text.ElideRight
                textFormat: Text.PlainText
            }
            RowLayout {
                Layout.topMargin: 2
                visible: root.more > 0 || root.muted
                spacing: 8

                Text {
                    visible: root.more > 0
                    text: `+${root.more} bildirim daha`
                    color: Colors.textFaint
                    font.family: Typography.family
                    font.pixelSize: 11
                }
                // Susturulmuş uygulama: tıklayınca susturma kalkar
                Text {
                    visible: root.muted
                    text: "Susturuldu · aç"
                    color: unmuteMouse.containsMouse ? Colors.text : Colors.textFaint
                    font.family: Typography.family
                    font.pixelSize: 11
                    font.underline: unmuteMouse.containsMouse

                    MouseArea {
                        id: unmuteMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.unmute()
                    }
                }
            }
        }
    }
}
