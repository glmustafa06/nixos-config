import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import qs.theme
import qs.components
import qs.services

// Pencere değiştirici (Alt+Tab): ekranın ortasında, uygulama simgeleri yan yana (macOS'taki gibi).
// Seçili simgenin zemini aydınlık; altında uygulamanın adı ve pencerenin başlığı. Başka alandaki
// pencerenin köşesinde alan numarası. Fareyle üstüne gelince seçilir, tıklayınca geçilir.
// Mantığı services/Switcher.qml'de; yalnızca açıldığı ekranda görünür.
PanelWindow {
    id: root

    required property var modelData
    screen: modelData

    readonly property bool active: Switcher.shown && (Switcher.screenName === "" || Switcher.screenName === (modelData?.name ?? ""))
    readonly property var items: Switcher.items
    readonly property var current: items[Switcher.index] ?? null

    // Çok pencere varsa simgeler küçülür: ekran genişliğinin en çok %85'i
    readonly property real maxRow: (screen?.width ?? 1920) * 0.85 - 28
    readonly property real cell: Math.max(56, Math.min(Metrics.switcherCell, Math.floor((maxRow + 6) / Math.max(1, items.length)) - 6))
    readonly property real iconSize: Math.round(cell * 0.72)

    // Farenin son yeri: seçim yalnızca fare gerçekten oynayınca değişir (değiştirici imlecin
    // altında açılınca seçim kendiliğinden kaymasın)
    property point lastMouse: Qt.point(-1, -1)

    visible: active
    color: "transparent"
    implicitWidth: panel.width
    implicitHeight: panel.height
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "desk-switcher"
    // Klavye burada: Alt'ın bırakılması da buradan yakalanır (Hyprland'in tuş takımına ek olarak)
    WlrLayershell.keyboardFocus: active ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    onActiveChanged: {
        lastMouse = Qt.point(-1, -1);
        if (active)
            Qt.callLater(() => keys.forceActiveFocus());
    }

    BackgroundEffect.blurRegion: Region {
        item: panel
        radius: panel.radius
    }

    Item {
        id: keys
        focus: true
        Keys.onPressed: event => {
            switch (event.key) {
            case Qt.Key_Escape:
                Switcher.cancel();
                break;
            case Qt.Key_Tab:
            case Qt.Key_Right:
                Switcher.next();
                break;
            case Qt.Key_Backtab:
            case Qt.Key_Left:
                Switcher.previous();
                break;
            case Qt.Key_Return:
            case Qt.Key_Enter:
                Switcher.commit();
                break;
            default:
                return;
            }
            event.accepted = true;
        }
        Keys.onReleased: event => {
            if (event.key === Qt.Key_Alt || event.key === Qt.Key_AltGr || event.key === Qt.Key_Meta) {
                Switcher.commit();
                event.accepted = true;
            }
        }
    }

    Rectangle {
        id: panel

        width: row.implicitWidth + 28
        height: row.implicitHeight + label.implicitHeight + 40
        radius: 24
        color: Colors.glass
        border.width: 1
        border.color: Colors.panelBorder

        GlassEdge {}

        Row {
            id: row

            anchors {
                top: parent.top
                topMargin: 14
                horizontalCenter: parent.horizontalCenter
            }
            spacing: 6

            Repeater {
                model: root.items

                Rectangle {
                    id: cellItem

                    required property var modelData
                    required property int index
                    readonly property string key: DockApps.keyOf(modelData)
                    readonly property bool selected: index === Switcher.index
                    // Başka alandaki pencere: köşede alan numarası
                    readonly property int workspaceId: modelData.workspace?.id ?? 0
                    readonly property bool elsewhere: workspaceId > 0 && workspaceId !== (WindowManager.workspace?.id ?? 0)

                    width: root.cell
                    height: root.cell
                    radius: Math.round(root.cell * 0.2)
                    color: selected ? Colors.switcherSelected : "transparent"

                    Behavior on color {
                        ColorAnimation { duration: 70 }
                    }

                    IconImage {
                        anchors.centerIn: parent
                        implicitSize: root.iconSize
                        source: DockApps.iconOf(cellItem.key)
                    }

                    Rectangle {
                        visible: cellItem.elsewhere
                        anchors {
                            right: parent.right
                            bottom: parent.bottom
                            margins: 5
                        }
                        width: Math.max(height, workspaceText.implicitWidth + 8)
                        height: 17
                        radius: 8.5
                        color: Colors.tooltip
                        border.width: 1
                        border.color: Colors.panelBorder

                        Text {
                            id: workspaceText
                            anchors.centerIn: parent
                            text: cellItem.workspaceId
                            color: Colors.textMuted
                            font.family: Typography.family
                            font.pixelSize: 10
                            font.weight: Font.DemiBold
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        onPositionChanged: mouse => {
                            const point = mapToItem(null, mouse.x, mouse.y);
                            const moved = root.lastMouse.x >= 0 && (point.x !== root.lastMouse.x || point.y !== root.lastMouse.y);
                            root.lastMouse = point;
                            if (moved)
                                Switcher.select(cellItem.index);
                        }
                        onClicked: {
                            Switcher.select(cellItem.index);
                            Switcher.commit();
                        }
                    }
                }
            }
        }

        // Seçilenin adı ve pencerenin başlığı
        Row {
            id: label

            readonly property string name: root.current ? DockApps.nameOf(DockApps.keyOf(root.current)) : ""
            readonly property string title: (root.current?.title ?? "").trim()

            anchors {
                top: row.bottom
                topMargin: 10
                horizontalCenter: parent.horizontalCenter
            }
            spacing: 8

            Text {
                id: nameText
                text: label.name
                color: Colors.text
                font.family: Typography.family
                font.pixelSize: Typography.body
                font.weight: Font.DemiBold
            }
            Text {
                visible: label.title !== "" && label.title !== label.name
                width: Math.min(implicitWidth, panel.width - nameText.implicitWidth - 48)
                text: label.title
                elide: Text.ElideMiddle
                color: Colors.textMuted
                font.family: Typography.family
                font.pixelSize: Typography.body
            }
        }
    }
}
