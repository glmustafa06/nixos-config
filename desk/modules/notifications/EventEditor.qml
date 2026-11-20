import QtQuick
import QtQuick.Layouts
import qs.theme
import qs.components
import qs.services
import qs.modules.controlcenter
import qs.settings

// Etkinlik ekleme ve düzenleme (takvimin altında, satırların yerinde açılır).
//   Ad · saat (boşsa tüm gün) · tarih · tekrar · hatırlatma
// Enter kaydeder, Esc vazgeçer. Yanlış yazılan saat ya da tarih kutunun altında söylenir.
ColumnLayout {
    id: root

    property var event: null    // düzenlenen etkinlik; null: yeni
    property date day           // yeni etkinliğin günü (takvimde seçili gün)

    property string repeat: "none"
    property int reminder: 10
    property string error: ""

    readonly property bool allDay: timeField.text.trim() === ""

    signal finished(date shownDay)  // kaydedildi ya da silindi: takvim o güne geçer
    signal canceled

    spacing: 8

    function load(source, shownDay) {
        event = source;
        day = shownDay;
        titleField.text = source?.title ?? "";
        timeField.text = source?.time ?? "";
        dateField.text = Events.formatDate(source ? source.date : Events.dayKey(shownDay));
        repeat = source?.repeat ?? "none";
        reminder = source?.reminder ?? Settings.s.calendar.reminder; // yenisinde Ayarlar → Bildirimler → Takvim
        error = "";
        confirmDelete = false;
        Qt.callLater(() => titleField.focusInput());
    }

    // Seçili gün değişti (yeni etkinlik yazarken takvimde başka güne tıklandı): tarih de değişir
    function setDay(shownDay) {
        day = shownDay;
        dateField.text = Events.formatDate(Events.dayKey(shownDay));
    }

    function save() {
        const title = titleField.text.trim();
        if (title === "") {
            error = "Etkinliğe bir ad yaz.";
            titleField.focusInput();
            return;
        }
        const time = Events.parseTime(timeField.text);
        if (time === null) {
            error = "Saati anlayamadım: 14:30 gibi yaz (boş bırakırsan tüm gün).";
            timeField.focusInput();
            return;
        }
        const date = Events.parseDate(dateField.text, day.getFullYear());
        if (date === null) {
            error = "Tarihi anlayamadım: 24.11.2026 gibi yaz.";
            dateField.focusInput();
            return;
        }
        // Tüm gün etkinliğinde "10 dk önce" gibi seçenek yok: o gün 09:00'a döner
        let remind = reminder;
        if (time === "" && remind > 0 && remind < 1440)
            remind = 0;
        const fields = {
            title: title,
            time: time,
            date: date,
            repeat: repeat,
            reminder: remind
        };
        if (event)
            Events.update(event.id, fields);
        else
            Events.add(fields);
        finished(Events.parseDay(date));
    }

    // Silme: tekrarlanan etkinlikte "yalnızca bu gün" ya da "hepsi" sorulur
    property bool confirmDelete: false
    function removeEvent(all) {
        if (!event)
            return;
        if (all || event.repeat === "none")
            Events.remove(event.id);
        else
            Events.skipDay(event.id, day);
        finished(day);
    }

    TextField {
        id: titleField
        Layout.fillWidth: true
        placeholder: "Etkinlik adı"
        onAccepted: root.save()
        onCanceled: root.canceled()
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: 8

        TextField {
            id: timeField
            Layout.fillWidth: true
            placeholder: "Saat (boşsa tüm gün)"
            onAccepted: root.save()
            onCanceled: root.canceled()
        }
        TextField {
            id: dateField
            Layout.preferredWidth: 118
            placeholder: "gg.aa.yyyy"
            onAccepted: root.save()
            onCanceled: root.canceled()
        }
    }

    // Tekrar
    Choice {
        label: "Tekrar"
        options: [["none", "Yok"], ["weekly", "Her hafta"], ["monthly", "Her ay"], ["yearly", "Her yıl"]]
        current: root.repeat
        onPicked: value => root.repeat = value
    }

    // Hatırlatma (tüm gün etkinliğinde saat yerine "o gün 09:00")
    Choice {
        label: "Hatırlat"
        options: root.allDay ? [[-1, "Yok"], [0, "O gün 09:00"], [1440, "1 gün önce"]] : [[-1, "Yok"], [0, "Vaktinde"], [10, "10 dk önce"], [60, "1 sa önce"], [1440, "1 gün önce"]]
        // Tüm güne geçince "10 dk önce" gibi bir seçim "o gün"de görünür
        current: root.allDay && root.reminder > 0 && root.reminder < 1440 ? 0 : root.reminder
        onPicked: value => root.reminder = value
    }

    Text {
        Layout.fillWidth: true
        visible: root.error !== ""
        text: root.error
        color: Colors.danger
        font.family: Typography.family
        font.pixelSize: 12
        wrapMode: Text.WordWrap
    }

    // Düğmeler: [Sil] ……… Vazgeç · Kaydet. Silme onayında: Bu gün · Hepsi · Vazgeç
    RowLayout {
        Layout.fillWidth: true
        Layout.topMargin: 2
        spacing: 8

        TextButton {
            visible: root.event !== null && !root.confirmDelete
            danger: true
            text: "Sil"
            onClicked: {
                if (root.event.repeat === "none")
                    root.removeEvent(true);
                else
                    root.confirmDelete = true;
            }
        }
        TextButton {
            visible: root.confirmDelete
            danger: true
            text: "Yalnızca bu gün"
            onClicked: root.removeEvent(false)
        }
        TextButton {
            visible: root.confirmDelete
            danger: true
            text: "Hepsi"
            onClicked: root.removeEvent(true)
        }
        Item {
            Layout.fillWidth: true
        }
        TextButton {
            text: "Vazgeç"
            onClicked: {
                if (root.confirmDelete)
                    root.confirmDelete = false;
                else
                    root.canceled();
            }
        }
        TextButton {
            visible: !root.confirmDelete
            accent: true
            text: "Kaydet"
            onClicked: root.save()
        }
    }

    // Seçenek satırı: başlık ve yan yana küçük düğmeler (seçili olan vurgu renginde)
    component Choice: RowLayout {
        id: choice

        property string label
        property var options: []    // [[değer, yazı], …]
        property var current
        signal picked(var value)

        Layout.fillWidth: true
        spacing: 8

        Text {
            Layout.preferredWidth: 58
            text: choice.label
            color: Colors.textMuted
            font.family: Typography.family
            font.pixelSize: 12
        }
        Flow {
            Layout.fillWidth: true
            spacing: 4

            Repeater {
                model: choice.options

                Rectangle {
                    id: chip

                    required property var modelData
                    readonly property bool selected: modelData[0] === choice.current

                    width: chipText.implicitWidth + 16
                    height: 24
                    radius: 12
                    color: selected ? Colors.accent : chipMouse.containsMouse ? Colors.buttonHover : Colors.button

                    Text {
                        id: chipText
                        anchors.centerIn: parent
                        text: chip.modelData[1]
                        color: chip.selected ? Colors.accentForeground : Colors.text
                        font.family: Typography.family
                        font.pixelSize: 11
                        font.weight: chip.selected ? Font.DemiBold : Font.Normal
                    }
                    MouseArea {
                        id: chipMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: choice.picked(chip.modelData[0])
                    }
                }
            }
        }
    }
}
