import QtQuick
import QtQuick.Layouts
import qs.theme
import qs.components
import qs.services

// Takvimde seçili günün etkinlikleri (takvimin altında).
//   Başlık: "Bugün" / "24 Kasım Salı" ……… [+]
//   Satır: renkli çizgi · ad · saat (ya da "Tüm gün"), tekrar, hatırlatma. Tıklayınca düzenlenir.
// Ekleme ve düzenleme aynı yerde açılır (EventEditor); açıkken satırlar gizlenir.
ColumnLayout {
    id: root

    property date day: new Date()
    readonly property var items: Events.eventsOn(day)
    // Düzenleyici: "" kapalı, "new" yeni etkinlik, yoksa düzenlenen etkinliğin kimliği
    property string editing: ""
    readonly property bool busy: editing !== ""

    signal daySelected(date day)   // kaydedilen etkinliğin günü (takvim oraya geçer)

    spacing: 2

    function startNew() {
        editing = "new";
        editor.load(null, day);
    }
    function edit(event) {
        editing = event.id;
        editor.load(event, day);
    }
    function close() {
        editing = "";
    }

    // Takvimde başka güne geçildi: yeni etkinlik yazılıyorsa tarihi değişir, düzenleme kapanır
    onDayChanged: {
        if (editing === "new")
            editor.setDay(day);
        else
            close();
    }

    RowLayout {
        Layout.fillWidth: true
        Layout.leftMargin: 2
        spacing: 6

        Text {
            Layout.fillWidth: true
            text: root.editing === "new" ? "Yeni etkinlik" : root.editing !== "" ? "Etkinliği düzenle" : Events.dayTitle(root.day)
            color: Colors.text
            font.family: Typography.family
            font.pixelSize: 13
            font.weight: Font.DemiBold
            elide: Text.ElideRight
        }
        // Yeni etkinlik
        Rectangle {
            visible: !root.busy
            implicitWidth: 26
            implicitHeight: 26
            radius: 13
            color: addMouse.containsMouse ? Colors.hover : "transparent"

            Icon {
                anchors.centerIn: parent
                name: "plus"
                size: 15
                strokeWidth: 2.3
                color: addMouse.containsMouse ? Colors.text : Colors.textMuted
            }
            MouseArea {
                id: addMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.startNew()
            }
        }
    }

    Text {
        Layout.leftMargin: 2
        Layout.topMargin: 2
        Layout.bottomMargin: 2
        visible: !root.busy && root.items.length === 0
        text: "Etkinlik yok"
        color: Colors.textFaint
        font.family: Typography.family
        font.pixelSize: 12
    }

    Repeater {
        model: root.busy ? [] : root.items

        EventRow {}
    }

    EventEditor {
        id: editor
        Layout.fillWidth: true
        Layout.topMargin: 4
        visible: root.busy
        onFinished: shownDay => {
            root.close();
            root.daySelected(shownDay);
        }
        onCanceled: root.close()
    }

    // ---------- Tek etkinlik ----------
    component EventRow: Rectangle {
        id: row

        required property var modelData
        readonly property var event: modelData

        // Üstüne gelince zemin açılır: soluk yazılar griye döner (okunur kalsın)
        readonly property color faint: rowMouse.containsMouse ? Colors.textMuted : Colors.textFaint

        Layout.fillWidth: true
        implicitHeight: 42
        radius: 10
        color: rowMouse.containsMouse ? Colors.hover : "transparent"

        RowLayout {
            anchors {
                fill: parent
                leftMargin: 6
                rightMargin: 8
            }
            spacing: 10

            Rectangle {
                implicitWidth: 3
                implicitHeight: 26
                radius: 1.5
                color: Colors.accent
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1

                Text {
                    Layout.fillWidth: true
                    text: row.event.title
                    color: Colors.text
                    font.family: Typography.family
                    font.pixelSize: 13
                    font.weight: Font.Medium
                    elide: Text.ElideRight
                }
                RowLayout {
                    spacing: 5

                    Text {
                        text: row.event.time || "Tüm gün"
                        color: Colors.textMuted
                        font.family: Typography.family
                        font.pixelSize: 11
                        font.features: {
                            "tnum": 1
                        }
                    }
                    Icon {
                        visible: row.event.repeat !== "none"
                        name: "repeat"
                        size: 11
                        strokeWidth: 2.4
                        color: row.faint
                    }
                    Text {
                        visible: row.event.repeat !== "none"
                        text: Events.repeatNames[row.event.repeat] ?? ""
                        color: row.faint
                        font.family: Typography.family
                        font.pixelSize: 11
                    }
                    Icon {
                        visible: (row.event.reminder ?? -1) >= 0
                        name: "bell"
                        size: 11
                        strokeWidth: 2.4
                        color: row.faint
                    }
                    Text {
                        visible: (row.event.reminder ?? -1) >= 0
                        text: Events.reminderText(row.event)
                        color: row.faint
                        font.family: Typography.family
                        font.pixelSize: 11
                    }
                }
            }
            Icon {
                visible: rowMouse.containsMouse
                name: "pencil"
                size: 13
                strokeWidth: 2.2
                color: Colors.textMuted
            }
        }

        MouseArea {
            id: rowMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.edit(row.event)
        }
    }
}
