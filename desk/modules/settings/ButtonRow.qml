import QtQuick

// Düğmeli satır: ButtonRow { title: "Duvar kâğıdı"; buttonText: "Değiştir…"; onClicked: … }
OptionRow {
    id: row

    property string buttonText
    property string buttonIcon
    property bool danger: false
    signal clicked

    PillButton {
        text: row.buttonText
        icon: row.buttonIcon
        danger: row.danger
        onClicked: row.clicked()
    }
}
