import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.theme
import qs.components

// Ay takvimi (bildirim merkezinin üstü). Haftalar pazartesi başlar; bugün vurgu renginde.
// Oklar ay değiştirir; başka bir aydayken "Bugün" düğmesi çıkar.
Rectangle {
    id: root

    // Gösterilen ay (gün önemsiz)
    property date month: new Date()
    // Bugün: saat gece yarısını geçince değişsin
    readonly property date today: clock.date

    function reset() {
        month = new Date();
    }
    function shift(step) {
        month = new Date(month.getFullYear(), month.getMonth() + step, 1);
    }

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    readonly property int year: month.getFullYear()
    readonly property int monthIndex: month.getMonth()
    // Ayın ilk gününden önceki boş günler (pazartesi = 0)
    readonly property int offset: (new Date(year, monthIndex, 1).getDay() + 6) % 7
    readonly property int days: new Date(year, monthIndex + 1, 0).getDate()
    readonly property int rows: Math.ceil((offset + days) / 7)
    readonly property bool showingToday: year === today.getFullYear() && monthIndex === today.getMonth()

    implicitHeight: column.implicitHeight + 24
    radius: 16
    color: Colors.tile

    ColumnLayout {
        id: column

        anchors {
            left: parent.left
            right: parent.right
            top: parent.top
            margins: 12
            leftMargin: 14
            rightMargin: 14
        }
        spacing: 8

        RowLayout {
            Layout.fillWidth: true

            Text {
                Layout.fillWidth: true
                text: Qt.locale("tr_TR").standaloneMonthName(root.monthIndex) + " " + root.year
                color: Colors.text
                font.family: Typography.family
                font.pixelSize: 15
                font.weight: Font.DemiBold
            }
            Rectangle {
                visible: !root.showingToday
                implicitWidth: todayLabel.implicitWidth + 16
                implicitHeight: 24
                radius: 12
                color: todayMouse.containsMouse ? Colors.hover : "transparent"

                Text {
                    id: todayLabel
                    anchors.centerIn: parent
                    text: "Bugün"
                    color: todayMouse.containsMouse ? Colors.text : Colors.textMuted
                    font.family: Typography.family
                    font.pixelSize: 12
                }
                MouseArea {
                    id: todayMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.reset()
                }
            }
            ArrowButton {
                icon: "chevron-left"
                onClicked: root.shift(-1)
            }
            ArrowButton {
                icon: "chevron-right"
                onClicked: root.shift(1)
            }
        }

        GridLayout {
            Layout.fillWidth: true
            columns: 7
            rowSpacing: 2
            columnSpacing: 0

            Repeater {
                model: ["Pt", "Sa", "Ça", "Pe", "Cu", "Ct", "Pa"]

                Text {
                    required property string modelData
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    text: modelData
                    color: Colors.textFaint
                    font.family: Typography.family
                    font.pixelSize: 11
                    font.weight: Font.DemiBold
                }
            }

            Repeater {
                model: root.rows * 7

                Item {
                    id: cell

                    required property int index
                    readonly property date date: new Date(root.year, root.monthIndex, 1 - root.offset + index)
                    readonly property bool inMonth: date.getMonth() === root.monthIndex
                    readonly property bool isToday: date.toDateString() === root.today.toDateString()

                    Layout.fillWidth: true
                    implicitHeight: 30

                    Rectangle {
                        anchors.centerIn: parent
                        width: 28
                        height: 28
                        radius: 14
                        visible: cell.isToday
                        color: Colors.accent
                    }
                    Text {
                        anchors.centerIn: parent
                        text: cell.date.getDate()
                        color: cell.isToday ? Colors.accentForeground : cell.inMonth ? Colors.text : Colors.textFaint
                        font.family: Typography.family
                        font.pixelSize: 13
                        font.weight: cell.isToday ? Font.Bold : Font.Normal
                        font.features: {
                            "tnum": 1
                        }
                    }
                }
            }
        }
    }

    component ArrowButton: Rectangle {
        id: button

        property string icon
        signal clicked

        implicitWidth: 26
        implicitHeight: 26
        radius: 13
        color: arrowMouse.containsMouse ? Colors.hover : "transparent"

        Icon {
            anchors.centerIn: parent
            name: button.icon
            size: 15
            strokeWidth: 2.2
            color: Colors.textMuted
        }
        MouseArea {
            id: arrowMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: button.clicked()
        }
    }
}
