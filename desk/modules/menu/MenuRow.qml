import QtQuick
import QtQuick.Layouts
import Quickshell.Widgets
import qs.theme
import qs.components

// Menüdeki tek satır: [onay] [simge] yazı ……… kısayol [›]
// Ayırıcı ve küçük başlık da bu bileşenle çizilir. Biçim: MenuPopup.qml'in başı.
Item {
    id: row

    required property var entry
    property bool highlighted: false
    property bool showCheck: false   // menüde işaretli bir satır varsa sütun ayrılır
    property bool showIcon: false    // menüde simgeli satır varsa sütun ayrılır

    readonly property bool separator: entry.separator === true
    readonly property bool header: entry.header === true
    readonly property bool hasSubmenu: (entry.submenu?.length ?? 0) > 0 || (entry.trayMenu ?? null) !== null
    readonly property bool selectable: entry.enabled !== false && !separator && !header
    readonly property color foreground: highlighted ? Colors.accentForeground : Colors.text

    signal hovered
    signal exited
    signal clicked

    implicitHeight: separator ? 11 : header ? 24 : Metrics.menuItemHeight
    implicitWidth: separator ? 0 : content.implicitWidth + 20
    opacity: entry.enabled === false ? 0.4 : 1

    // Ayırıcı
    Rectangle {
        visible: row.separator
        anchors {
            left: parent.left
            right: parent.right
            leftMargin: 10
            rightMargin: 10
            verticalCenter: parent.verticalCenter
        }
        height: 1
        color: Colors.menuSeparator
    }

    // Vurgu (üstüne gelince ya da klavyeyle seçilince)
    Rectangle {
        anchors.fill: parent
        visible: row.highlighted && row.selectable
        radius: 8
        color: Colors.accent
    }

    RowLayout {
        id: content

        visible: !row.separator
        anchors {
            left: parent.left
            right: parent.right
            leftMargin: 10
            rightMargin: 10
            verticalCenter: parent.verticalCenter
        }
        spacing: 8

        // Onay işareti
        Item {
            visible: row.showCheck
            implicitWidth: 14
            implicitHeight: 14

            Icon {
                anchors.centerIn: parent
                visible: row.entry.checked === true
                name: "check"
                size: 14
                strokeWidth: 2.6
                color: row.foreground
            }
        }

        // Simge: çizgi simge, düzen simgesi ya da resim
        Item {
            visible: row.showIcon
            Layout.rightMargin: 2
            implicitWidth: 16
            implicitHeight: 16

            Icon {
                anchors.centerIn: parent
                visible: (row.entry.icon ?? "") !== ""
                name: row.entry.icon ?? ""
                size: 16
                strokeWidth: 2
                color: row.foreground
            }
            LayoutIcon {
                anchors.centerIn: parent
                visible: (row.entry.layoutIcon ?? "") !== ""
                layout: row.entry.layoutIcon ?? "dwindle"
                size: 16
                color: row.foreground
            }
            IconImage {
                anchors.centerIn: parent
                visible: (row.entry.image ?? "") !== ""
                source: row.entry.image ?? ""
                implicitSize: 16
            }
        }

        Text {
            text: row.entry.text ?? ""
            color: row.header ? Colors.textFaint : row.foreground
            font.family: Typography.family
            font.pixelSize: row.header ? Typography.small : Typography.body
            font.weight: row.header ? Font.DemiBold : Font.Normal
            renderType: Text.NativeRendering
            elide: Text.ElideRight
            Layout.fillWidth: true
            Layout.maximumWidth: 360
        }

        // Kısayol ya da sağdaki bilgi
        Text {
            visible: text !== ""
            Layout.leftMargin: 24
            text: row.entry.shortcut ?? ""
            color: row.highlighted && row.selectable ? Qt.rgba(row.foreground.r, row.foreground.g, row.foreground.b, 0.7) : Colors.textFaint
            font.family: Typography.family
            font.pixelSize: Typography.small
            font.letterSpacing: 0.3
            renderType: Text.NativeRendering
        }

        Icon {
            visible: row.hasSubmenu
            Layout.leftMargin: 16
            name: "chevron-right"
            size: 14
            strokeWidth: 2.2
            color: row.highlighted ? row.foreground : Colors.textFaint
        }
    }

    MouseArea {
        anchors.fill: parent
        enabled: row.selectable
        hoverEnabled: true
        onEntered: row.hovered()
        onExited: row.exited()
        onClicked: row.clicked()
    }
}
