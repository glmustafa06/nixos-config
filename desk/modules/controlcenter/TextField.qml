import QtQuick
import qs.theme

// Tek satırlık yazı kutusu (ağ adı, şifre, cihaz adı)
Rectangle {
    id: root

    property alias text: input.text
    property string placeholder
    property bool password: false

    signal accepted
    signal canceled

    function focusInput() {
        input.forceActiveFocus();
    }

    implicitHeight: 32
    implicitWidth: 200
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
        echoMode: root.password ? TextInput.Password : TextInput.Normal
        color: Colors.text
        selectionColor: Colors.accent
        selectedTextColor: Colors.accentForeground
        font.family: Typography.family
        font.pixelSize: Typography.body
        clip: true

        Keys.onReturnPressed: root.accepted()
        Keys.onEnterPressed: root.accepted()
        Keys.onEscapePressed: root.canceled()

        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: input.text === ""
            text: root.placeholder
            color: Colors.textFaint
            font: input.font
        }
    }
}
