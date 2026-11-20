import QtQuick
import qs.theme
import qs.components

// Büyüteçli arama kutusu; yazı varken sağda temizle düğmesi.
// Esc önce yazıyı siler, yazı yoksa escaped() ve tuş üste geçer. Yukarı/aşağı: moved(±1).
Rectangle {
    id: root

    property alias text: input.text
    property string placeholder: "Ara"
    property alias inputItem: input
    signal accepted
    signal escaped
    signal moved(int step)

    function focusInput() {
        input.forceActiveFocus();
    }

    implicitWidth: 200
    implicitHeight: 30
    radius: 8
    color: Colors.field
    border.width: 1
    border.color: input.activeFocus ? Colors.accent : Colors.panelBorder

    Icon {
        id: glass
        anchors {
            left: parent.left
            leftMargin: 9
            verticalCenter: parent.verticalCenter
        }
        name: "search"
        size: 14
        strokeWidth: 2.3
        color: Colors.textMuted
    }

    TextInput {
        id: input
        anchors {
            left: glass.right
            leftMargin: 7
            right: clear.left
            rightMargin: 4
            verticalCenter: parent.verticalCenter
        }
        color: Colors.text
        selectionColor: Colors.accent
        selectedTextColor: Colors.accentForeground
        font.family: Typography.family
        font.pixelSize: Typography.body - 1
        clip: true

        Keys.onReturnPressed: root.accepted()
        Keys.onEnterPressed: root.accepted()
        Keys.onUpPressed: root.moved(-1)
        Keys.onDownPressed: root.moved(1)
        // Yazı varken siler; yoksa tuş yukarı geçer (pencere kapanır)
        Keys.onEscapePressed: event => {
            if (input.text !== "") {
                input.text = "";
            } else {
                root.escaped();
                event.accepted = false;
            }
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: input.text === ""
            text: root.placeholder
            color: Colors.textFaint
            font: input.font
        }
    }

    Item {
        id: clear
        anchors {
            right: parent.right
            rightMargin: 6
            verticalCenter: parent.verticalCenter
        }
        width: input.text !== "" ? 18 : 0
        height: 18

        Rectangle {
            anchors.fill: parent
            visible: input.text !== ""
            radius: 9
            color: clearMouse.containsMouse ? Colors.segmentSelected : Colors.circleOff

            Icon {
                anchors.centerIn: parent
                name: "x"
                size: 10
                strokeWidth: 2.6
                color: Colors.text
            }
            MouseArea {
                id: clearMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    input.text = "";
                    input.forceActiveFocus();
                }
            }
        }
    }
}
