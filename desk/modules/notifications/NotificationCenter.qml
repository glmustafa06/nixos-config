import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.theme
import qs.components
import qs.services

// Bildirim merkezi: saate tıklayınca barın altında, sağda açılır (maketteki gibi).
// Üstte ay takvimi, altında uygulamaya göre gruplu bildirimler (en yenisi başta).
//   - Grubun yalnızca en yeni bildirimi görünür ("+N bildirim daha"); tıklayınca grup açılır.
//   - Tek bildirime tıklayınca uygulamaya gidilir ve merkez kapanır; × yalnızca onu siler.
//   - Kapalı gruptaki × bütün grubu siler.
// Açılıp kapanmasını bar yönetir (Bar.qml: openMenu), kontrol merkeziyle aynı düzen.
PanelWindow {
    id: root

    property var controller: null
    readonly property string menuKey: "notifications"
    readonly property bool open: controller !== null && controller.openMenu === menuKey

    // Odak yakalama için (bar ile birlikte)
    readonly property var windows: visible ? [root] : []

    // Açık gruplar: uygulama adı → true. Merkez kapanınca hepsi kapanır.
    property var expandedGroups: ({})

    function setExpanded(appName, on) {
        const map = Object.assign({}, expandedGroups);
        if (on)
            map[appName] = true;
        else
            delete map[appName];
        expandedGroups = map;
    }
    function close() {
        controller?.closeMenus();
    }
    function activate(entry) {
        Notifications.activate(entry);
        close();
    }
    function handleKey(event) {
        if (event.key !== Qt.Key_Escape)
            return false;
        close();
        return true;
    }

    onOpenChanged: {
        controller?.menuOpened(root, open);
        Ui.notificationCenterOpen = open;
        if (open) {
            calendar.reset();
            list.contentY = 0;
        } else {
            expandedGroups = {};
        }
    }

    visible: open
    color: "transparent"
    screen: controller?.screen ?? null

    anchors {
        top: true
        right: true
    }
    margins.top: Metrics.popoutTop
    margins.right: Metrics.popoutRight
    exclusionMode: ExclusionMode.Ignore
    focusable: true
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "desk-notification-center"

    // Ekrana sığmayan bildirimler kaydırılır
    readonly property real maxHeight: (screen?.height ?? 1080) - Metrics.popoutTop - Metrics.notificationBottomGap

    implicitWidth: Metrics.controlCenterWidth
    implicitHeight: panel.implicitHeight

    BackgroundEffect.blurRegion: Region {
        item: panel
        radius: panel.radius
    }

    Rectangle {
        id: panel

        width: parent.width
        height: parent.height
        implicitHeight: Math.min(root.maxHeight, column.implicitHeight + 24)
        radius: 24
        color: Colors.panel
        border.width: 1
        border.color: Colors.panelBorder

        FocusScope {
            anchors.fill: parent
            focus: true
            Keys.onPressed: event => event.accepted = root.handleKey(event)

            ColumnLayout {
                id: column

                anchors {
                    left: parent.left
                    right: parent.right
                    top: parent.top
                    margins: 12
                }
                spacing: 10

                Calendar {
                    id: calendar
                    Layout.fillWidth: true
                }

                // Başlık: Bildirimler ……… Tümünü temizle
                RowLayout {
                    id: header
                    Layout.fillWidth: true
                    Layout.leftMargin: 6
                    Layout.rightMargin: 2
                    Layout.topMargin: 2

                    Text {
                        Layout.fillWidth: true
                        text: "Bildirimler"
                        color: Colors.text
                        font.family: Typography.family
                        font.pixelSize: 13
                        font.weight: Font.DemiBold
                    }
                    LinkButton {
                        visible: Notifications.history.length > 0
                        text: "Tümünü temizle"
                        onClicked: Notifications.clearAll()
                    }
                }

                // Rahatsız etme açıkken bildirimler adada çıkmaz; burada söylenir
                Rectangle {
                    id: dndRow
                    Layout.fillWidth: true
                    visible: QuickSettings.doNotDisturb
                    implicitHeight: 36
                    radius: 12
                    color: Colors.tile

                    RowLayout {
                        anchors {
                            fill: parent
                            leftMargin: 12
                            rightMargin: 8
                        }
                        spacing: 8

                        Icon {
                            name: "moon"
                            size: 15
                            strokeWidth: 2.2
                            color: Colors.accent
                        }
                        Text {
                            Layout.fillWidth: true
                            text: "Rahatsız etme açık"
                            color: Colors.textMuted
                            font.family: Typography.family
                            font.pixelSize: 12
                            elide: Text.ElideRight
                        }
                        LinkButton {
                            text: "Kapat"
                            onClicked: QuickSettings.setDoNotDisturb(false)
                        }
                    }
                }

                // Boşken
                Rectangle {
                    Layout.fillWidth: true
                    visible: Notifications.history.length === 0
                    implicitHeight: 84
                    radius: 16
                    color: Colors.tile

                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: 6

                        Icon {
                            Layout.alignment: Qt.AlignHCenter
                            name: "bell"
                            size: 20
                            strokeWidth: 2
                            color: Colors.textFaint
                        }
                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: "Bildirim yok"
                            color: Colors.textFaint
                            font.family: Typography.family
                            font.pixelSize: 12
                        }
                    }
                }

                // Gruplar: yer kalmazsa kaydırılır
                Flickable {
                    id: list

                    Layout.fillWidth: true
                    // Takvim, başlık ve (varsa) rahatsız etme satırından kalan yer
                    readonly property real room: root.maxHeight - 24 - calendar.height - header.height - header.Layout.topMargin - column.spacing * 2 - (dndRow.visible ? dndRow.height + column.spacing : 0)
                    Layout.preferredHeight: Math.min(contentHeight, Math.max(120, room))
                    visible: Notifications.history.length > 0
                    contentHeight: groups.implicitHeight
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    interactive: contentHeight > height

                    Column {
                        id: groups

                        width: list.width
                        spacing: 8

                        move: Transition {
                            NumberAnimation {
                                property: "y"
                                duration: Metrics.durationNormal
                                easing.type: Easing.OutCubic
                            }
                        }

                        Repeater {
                            // Grup başına bir satır; aynı grup yeni bildirim alınca baştan kurulmaz
                            model: ScriptModel {
                                values: Notifications.groups.map(g => g.appName)
                            }

                            Group {}
                        }
                    }
                }
            }
        }
    }

    // ---------- Bir uygulamanın bildirimleri ----------
    component Group: ColumnLayout {
        id: group

        required property string modelData
        readonly property var info: Notifications.groups.find(g => g.appName === modelData) ?? null
        readonly property var entries: info?.entries ?? []
        readonly property bool expanded: root.expandedGroups[modelData] === true && entries.length > 1
        readonly property bool muted: Notifications.isMuted(modelData)

        width: groups.width
        spacing: 4

        // Açık grubun başlığı: uygulama adı ……… Daha az · Temizle
        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: 6
            Layout.rightMargin: 2
            Layout.topMargin: 6
            Layout.bottomMargin: 2
            visible: group.expanded

            Text {
                Layout.fillWidth: true
                text: group.modelData
                color: Colors.textMuted
                font.family: Typography.family
                font.pixelSize: 12
                font.weight: Font.DemiBold
                elide: Text.ElideRight
            }
            LinkButton {
                text: "Daha az"
                onClicked: root.setExpanded(group.modelData, false)
            }
            LinkButton {
                text: "Temizle"
                onClicked: Notifications.removeGroup(group.modelData)
            }
        }

        Repeater {
            // Kapalı grupta yalnızca en yenisi
            model: ScriptModel {
                values: (group.expanded ? group.entries : group.entries.slice(0, 1)).map(e => e.key)
            }

            NotificationCard {
                required property var modelData
                required property int index

                Layout.fillWidth: true
                entry: group.entries.find(e => e.key === modelData) ?? null
                more: group.expanded ? 0 : group.entries.length - 1
                muted: index === 0 && group.muted
                showApp: !group.expanded

                onClicked: {
                    if (!entry)
                        return;
                    if (more > 0)
                        root.setExpanded(group.modelData, true);
                    else
                        root.activate(entry);
                }
                // Kapalı yığındaki × bütün grubu siler
                onRemoved: {
                    if (more > 0)
                        Notifications.removeGroup(group.modelData);
                    else if (entry)
                        Notifications.remove(entry);
                }
                onUnmute: Notifications.unmuteApp(group.modelData)
            }
        }
    }

    // Yazı düğmesi ("Tümünü temizle", "Kapat")
    component LinkButton: Rectangle {
        id: link

        property string text
        signal clicked

        implicitWidth: label.implicitWidth + 16
        implicitHeight: 24
        radius: 12
        color: linkMouse.containsMouse ? Colors.hover : "transparent"

        Text {
            id: label
            anchors.centerIn: parent
            text: link.text
            color: linkMouse.containsMouse ? Colors.text : Colors.textMuted
            font.family: Typography.family
            font.pixelSize: 12
        }
        MouseArea {
            id: linkMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: link.clicked()
        }
    }
}
