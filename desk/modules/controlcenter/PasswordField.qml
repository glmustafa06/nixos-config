import QtQuick
import QtQuick.Layouts
import qs.theme

// Wi-Fi şifresi kutusu: yazıp Enter'a basınca bağlanır, Esc vazgeçer
ColumnLayout {
    id: root

    property string error: ""

    signal submitted(string password)
    signal canceled

    spacing: 6

    // Görünür olunca imleç kutuya gelsin (gerektiğinde kurulduğu için açılışta da)
    onVisibleChanged: {
        if (visible) {
            input.text = "";
            input.forceActiveFocus();
        }
    }
    Component.onCompleted: Qt.callLater(() => {
        if (visible)
            input.forceActiveFocus();
    })

    RowLayout {
        Layout.fillWidth: true
        spacing: 8

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 32
            radius: 9
            color: Colors.field
            border.width: 1
            border.color: input.activeFocus ? Colors.accent : Colors.panelBorder

            TextInput {
                id: input
                anchors {
                    fill: parent
                    leftMargin: 10
                    rightMargin: 10
                }
                verticalAlignment: TextInput.AlignVCenter
                echoMode: TextInput.Password
                color: Colors.text
                selectionColor: Colors.accent
                selectedTextColor: Colors.accentForeground
                font.family: Typography.family
                font.pixelSize: Typography.body
                clip: true

                Keys.onReturnPressed: root.submit()
                Keys.onEnterPressed: root.submit()
                Keys.onEscapePressed: root.canceled()

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: input.text === ""
                    text: "Şifre"
                    color: Colors.textFaint
                    font: input.font
                }
            }
        }

        Rectangle {
            implicitWidth: label.implicitWidth + 24
            implicitHeight: 32
            radius: 9
            color: input.text.length >= 8 ? Colors.accent : Colors.circleOff

            Text {
                id: label
                anchors.centerIn: parent
                text: "Bağlan"
                color: input.text.length >= 8 ? Colors.accentForeground : Colors.textMuted
                font.family: Typography.family
                font.pixelSize: Typography.small
                font.weight: Font.DemiBold
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.submit()
            }
        }
    }

    Text {
        Layout.fillWidth: true
        visible: root.error !== ""
        text: root.error
        color: Colors.warning
        font.family: Typography.family
        font.pixelSize: Typography.small
        wrapMode: Text.WordWrap
    }

    // WPA şifreleri en az 8 karakter
    function submit() {
        if (input.text.length >= 8)
            root.submitted(input.text);
    }
}
