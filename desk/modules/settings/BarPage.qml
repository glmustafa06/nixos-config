import QtQuick
import QtQuick.Layouts
import qs.theme
import qs.components
import qs.services
import qs.settings

// Üst bar: sağdaki simgelerin sırası (sürükle) ve görünürlüğü, saat, pil yüzdesi, menüler, görünüm
SettingsPage {
    id: page

    title: "Üst bar"

    readonly property var bar: Settings.s.bar

    // Saat önizlemesi (Bar.qml'deki biçimin aynısı)
    readonly property string clockText: {
        const parts = [];
        if (bar.weekday)
            parts.push("ddd");
        if (bar.date)
            parts.push("d MMM");
        const day = parts.join(" ");
        const time = bar.seconds ? "HH:mm:ss" : "HH:mm";
        return now.toLocaleString(Qt.locale("tr_TR"), day === "" ? time : day + "  " + time);
    }
    property date now: new Date()
    Timer {
        running: page.bar.seconds
        repeat: true
        interval: 1000
        onTriggered: page.now = new Date()
    }

    // ---------- Sıra ----------
    // Sürüklenirken geçici sıra (bırakınca Ayarlar'a yazılır)
    property var dragOrder: null
    property string dragId: ""
    readonly property var order: dragOrder ?? Settings.barItems.map(item => item.id)
    function shown(id) {
        return Settings.barItems.find(item => item.id === id)?.shown ?? true;
    }
    function setShown(id, on) {
        const hidden = Settings.s.bar.hidden.filter(other => other !== id);
        if (!on)
            hidden.push(id);
        Settings.set("bar.hidden", hidden);
    }
    function commitOrder(ids) {
        Settings.set("bar.order", ids);
    }

    // Önizleme: barın sağ ucu, gerçek sırayla
    SettingsSection {
        title: "Önizleme"

        Item {
            Layout.fillWidth: true
            implicitHeight: 64

            Rectangle {
                anchors {
                    fill: parent
                    margins: 10
                }
                radius: 9
                color: Colors.barDarkBackground
                border.width: 1
                border.color: Colors.panelBorder

                Row {
                    id: preview
                    anchors {
                        right: parent.right
                        rightMargin: 14
                        verticalCenter: parent.verticalCenter
                    }
                    spacing: 0

                    Repeater {
                        model: page.order.filter(id => page.shown(id))

                        Item {
                            id: previewItem

                            required property string modelData
                            required property int index
                            readonly property var visibleIds: page.order.filter(id => page.shown(id))
                            readonly property string next: visibleIds[index + 1] ?? ""
                            readonly property bool groupEnd: next !== "" && Settings.barItemInfo[next].group !== Settings.barItemInfo[modelData].group

                            width: glyph.implicitWidth + 16 + (groupEnd ? Metrics.barGroupGap : 0)
                            height: 28
                            opacity: page.dragId === modelData ? 0.5 : 1

                            Rectangle {
                                visible: page.dragId === previewItem.modelData
                                x: 0
                                width: glyph.implicitWidth + 16
                                height: parent.height
                                radius: 7
                                color: Colors.segmentSelected
                            }
                            BarGlyph {
                                id: glyph
                                x: 8
                                anchors.verticalCenter: parent.verticalCenter
                                itemId: previewItem.modelData
                                clockText: page.clockText
                                color: Colors.barDarkText
                            }
                        }
                    }
                }
            }
        }
    }

    SettingsSection {
        title: "Sağdaki simgeler"
        footer: "Sürükleyerek sırala. Kapattıkların bardan kalkar; kontrol merkezinden yine erişilir."

        Item {
            id: list

            readonly property int rowHeight: 48
            readonly property var ids: Settings.defaults.bar.order
            // Sürüklenenin yeri (liste içinde, üst kenarı)
            property real dragY: 0
            property real grabOffset: 0

            Layout.fillWidth: true
            implicitHeight: ids.length * rowHeight

            Repeater {
                model: list.ids

                Item {
                    id: itemRow

                    required property string modelData
                    readonly property var info: Settings.barItemInfo[modelData]
                    readonly property int position: page.order.indexOf(modelData)
                    readonly property bool dragging: page.dragId === modelData
                    readonly property bool on: page.shown(modelData)

                    width: list.width
                    height: list.rowHeight
                    y: dragging ? list.dragY : position * list.rowHeight
                    z: dragging ? 2 : 1

                    Behavior on y {
                        enabled: !itemRow.dragging
                        NumberAnimation {
                            duration: Metrics.durationNormal
                            easing.type: Easing.OutCubic
                        }
                    }

                    // Sürüklenirken kartın üstünde yüzer
                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: 2
                        visible: itemRow.dragging
                        radius: 10
                        color: Colors.settingsBackground
                        border.width: 1
                        border.color: Colors.panelBorder
                    }
                    Rectangle {
                        visible: itemRow.position > 0 && !itemRow.dragging && page.order[itemRow.position - 1] !== page.dragId
                        anchors {
                            top: parent.top
                            left: parent.left
                            leftMargin: 14
                            right: parent.right
                        }
                        height: 1
                        color: Colors.settingsSeparator
                    }

                    // Bütün satır tutulup sürüklenir (anahtar hariç)
                    MouseArea {
                        id: dragArea

                        anchors.fill: parent
                        preventStealing: true
                        hoverEnabled: true
                        cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor

                        onPressed: mouse => {
                            const point = mapToItem(list, mouse.x, mouse.y);
                            list.grabOffset = point.y - itemRow.y;
                            list.dragY = itemRow.y;
                            page.dragOrder = page.order.slice();
                            page.dragId = itemRow.modelData;
                        }
                        onPositionChanged: mouse => {
                            if (!pressed || page.dragId !== itemRow.modelData)
                                return;
                            const point = mapToItem(list, mouse.x, mouse.y);
                            list.dragY = Math.max(0, Math.min(list.height - list.rowHeight, point.y - list.grabOffset));
                            const target = Math.max(0, Math.min(list.ids.length - 1, Math.round(list.dragY / list.rowHeight)));
                            const current = page.dragOrder.indexOf(itemRow.modelData);
                            if (target !== current) {
                                const next = page.dragOrder.slice();
                                next.splice(current, 1);
                                next.splice(target, 0, itemRow.modelData);
                                page.dragOrder = next;
                            }
                        }
                        onReleased: page.finishDrag()
                        onCanceled: page.finishDrag()
                    }

                    Icon {
                        anchors {
                            left: parent.left
                            leftMargin: 10
                            verticalCenter: parent.verticalCenter
                        }
                        name: "grip-vertical"
                        size: 16
                        color: Colors.textFaint
                    }
                    Rectangle {
                        id: glyphBox
                        anchors {
                            left: parent.left
                            leftMargin: 34
                            verticalCenter: parent.verticalCenter
                        }
                        width: 30
                        height: 26
                        radius: 7
                        color: Colors.segment

                        BarGlyph {
                            anchors.centerIn: parent
                            itemId: itemRow.modelData
                            clockText: "9:41"
                            color: itemRow.on ? Colors.text : Colors.textFaint
                            scale: itemRow.modelData === "tray" ? 0.75 : itemRow.modelData === "clock" ? 0.8 : 1
                        }
                    }
                    Column {
                        anchors {
                            left: glyphBox.right
                            leftMargin: 10
                            right: toggle.left
                            rightMargin: 12
                            verticalCenter: parent.verticalCenter
                        }
                        spacing: 1

                        Text {
                            width: parent.width
                            text: itemRow.info.name
                            elide: Text.ElideRight
                            color: itemRow.on ? Colors.text : Colors.textMuted
                            font.family: Typography.family
                            font.pixelSize: Typography.body
                        }
                        Text {
                            width: parent.width
                            visible: itemRow.info.detail !== ""
                            text: itemRow.info.detail
                            elide: Text.ElideRight
                            color: Colors.textMuted
                            font.family: Typography.family
                            font.pixelSize: Typography.small
                        }
                    }
                    Switch {
                        id: toggle
                        anchors {
                            right: parent.right
                            rightMargin: 14
                            verticalCenter: parent.verticalCenter
                        }
                        visible: itemRow.info.fixed !== true
                        checked: itemRow.on
                        onToggled: page.setShown(itemRow.modelData, !itemRow.on)
                    }
                }
            }
        }
    }

    function finishDrag() {
        if (dragId === "")
            return;
        const ids = dragOrder;
        dragId = "";
        dragOrder = null;
        if (ids && ids.join() !== Settings.barItems.map(item => item.id).join())
            commitOrder(ids);
    }

    SettingsSection {
        title: "Saat"

        SwitchRow {
            title: "Haftanın günü"
            setting: "bar.weekday"
        }
        SwitchRow {
            title: "Tarih"
            setting: "bar.date"
        }
        SwitchRow {
            title: "Saniyeler"
            setting: "bar.seconds"
        }
    }

    SettingsSection {
        title: "Diğer"

        SwitchRow {
            title: "Pil yüzdesi"
            setting: "bar.batteryPercent"
        }
        SwitchRow {
            title: "Pencere ve Düzen menüleri"
            subtitle: "Solda, uygulamanın adının yanında"
            setting: "bar.menus"
        }
        ChoiceRow {
            title: "Bar"
            subtitle: Settings.s.appearance.barTone === "auto" ? "Duvar kâğıdının üst kısmına göre koyu ya da açık" : "Her duvar kâğıdında aynı"
            setting: "appearance.barTone"
            options: [["auto", "Otomatik"], ["dark", "Koyu"], ["light", "Açık"]]
        }
    }
}
