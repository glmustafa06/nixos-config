import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import qs.theme
import qs.components
import qs.services
import qs.settings

// Ayarlar penceresi (Super+Virgül, kontrol merkezindeki çark, aramada "Ayarlar").
// Solda cam kenar çubuğu (arama ve bölümler), sağda seçili bölümün sayfası. Her değişiklik anında
// uygulanır ve ~/nixos-config/desk-ayarlar.json'a yazılır (settings/Settings.qml).
// Hyprland onu ortada yüzer açar (hypr/config/rules.lua → desk-settings). Esc kapatır.
FloatingWindow {
    id: root

    title: "Ayarlar"
    color: "transparent"
    implicitWidth: Metrics.settingsWidth
    implicitHeight: Metrics.settingsHeight
    minimumSize: Qt.size(760, 520)

    // Hyprland pencereyi kapatınca (Super+Q, Alt+F4)
    onClosed: Ui.settingsOpen = false

    // Açıkken yeniden istenince (başka alanda kalmış olabilir) öne gelir
    Connections {
        target: Ui
        function onSettingsRaiseChanged() {
            const window = Hyprland.toplevels.values.find(t => WindowManager.appIdOf(t) === "desk-settings");
            if (window)
                WindowManager.focus(window);
        }
    }

    readonly property var sections: [
        { id: "appearance", title: "Görünüm", icon: "palette", group: 0, keywords: "vurgu renk tema saydamlık hareket animasyon duvar kâğıdı" },
        { id: "windows", title: "Pencereler", icon: "app-window", group: 0, keywords: "boşluk köşe yuvarlak gölge karartma" },
        { id: "bar", title: "Üst bar", icon: "panel-top", group: 0, keywords: "simge sıra sırala saat tarih gün saniye pil yüzde menü koyu açık" },
        { id: "dock", title: "Dock", icon: "panel-bottom", group: 0, keywords: "simge boyut gizle rozet nokta sabitle çöp indirilenler" },
        { id: "notifications", title: "Bildirimler", icon: "bell", group: 1, keywords: "rahatsız etme ada süre uygulama takvim hatırlatma sessiz" },
        { id: "display", title: "Ekran", icon: "sun-medium", group: 1, keywords: "parlaklık gece ışığı sıcaklık zamanla monitör çözünürlük hz" },
        { id: "power", title: "Pil ve güç", icon: "battery-charging", group: 1, keywords: "pil koruma şarj güç modu boşta karart kilit uyku kapak tasarruf performans" },
        { id: "input", title: "Klavye ve fare", icon: "keyboard", group: 2, keywords: "düzen türkçe f q ingilizce tekrar fare işaretçi dokunmatik kaydırma tıklama odak" },
        { id: "screenshot", title: "Ekran görüntüsü", icon: "camera", group: 2, keywords: "kayıt video önizleme kare hızı imleç ses print" },
        { id: "shortcuts", title: "Kısayollar", icon: "command", group: 2, keywords: "tuş kısayol klavye super" },
        { id: "about", title: "Hakkında", icon: "info", group: 3, keywords: "sistem sürüm bilgisayar işlemci bellek disk sıfırla dosya" }
    ]

    readonly property string page: sections.some(s => s.id === Ui.settingsPage) ? Ui.settingsPage : "appearance"

    // Kenar çubuğundaki arama: ad ve anahtar sözcüklerde
    property string query: ""
    // Adında geçenler önce, sonra yalnızca anahtar sözcüklerinde geçenler
    readonly property var shownSections: {
        const q = query.trim().toLocaleLowerCase("tr");
        if (q === "")
            return sections;
        const inTitle = sections.filter(s => s.title.toLocaleLowerCase("tr").includes(q));
        const inKeywords = sections.filter(s => !inTitle.includes(s) && s.keywords.toLocaleLowerCase("tr").includes(q));
        return inTitle.concat(inKeywords);
    }

    function select(id) {
        Ui.settingsPage = id;
    }

    // Aramada yukarı/aşağı: görünenler arasında
    function step(direction) {
        const list = shownSections;
        if (list.length === 0)
            return;
        const at = list.findIndex(s => s.id === page);
        const next = at < 0 ? 0 : Math.max(0, Math.min(list.length - 1, at + direction));
        select(list[next].id);
    }

    // Yazdıkça en iyi sonuç açılır
    onQueryChanged: {
        if (query.trim() !== "" && shownSections.length > 0)
            select(shownSections[0].id);
    }

    // Bütün pencere: içteki yazı kutuları kullanmadığı tuşlar buraya çıkar (Esc kapatır)
    Item {
        id: keys
        anchors.fill: parent
        focus: true

        Keys.onEscapePressed: Ui.settingsOpen = false
        Keys.onPressed: event => {
            // Ctrl+F ya da yazmaya başlamak: arama
            if ((event.key === Qt.Key_F && (event.modifiers & Qt.ControlModifier)) || (event.text.length === 1 && event.text.trim() !== "" && !(event.modifiers & (Qt.ControlModifier | Qt.AltModifier)) && !search.inputItem.activeFocus)) {
                search.focusInput();
                if (event.key !== Qt.Key_F || !(event.modifiers & Qt.ControlModifier))
                    search.text += event.text;
                event.accepted = true;
            } else if (event.key === Qt.Key_Up || event.key === Qt.Key_Down) {
                if (!(event.modifiers & Qt.ControlModifier))
                    return;
                root.step(event.key === Qt.Key_Down ? 1 : -1);
                event.accepted = true;
            }
        }

        // ---------- Kenar çubuğu ----------
        Rectangle {
            id: sidebar

            anchors {
                left: parent.left
                top: parent.top
                bottom: parent.bottom
            }
            width: Metrics.settingsSidebar
            color: Colors.glass

            GlassEdge {}

            // Üst şerit: pencereyi taşımak için tutulur (başlık çubuğu yok)
            MouseArea {
                anchors {
                    left: parent.left
                    right: parent.right
                    top: parent.top
                }
                height: 46
                onPressed: root.startSystemMove()
            }

            // Kapat
            Rectangle {
                id: closeButton
                anchors {
                    left: parent.left
                    leftMargin: 14
                    top: parent.top
                    topMargin: 15
                }
                width: 14
                height: 14
                radius: 7
                color: closeMouse.containsMouse ? Colors.recordDot : Colors.circleOff
                border.width: 1
                border.color: Colors.panelBorder

                Icon {
                    anchors.centerIn: parent
                    visible: closeMouse.containsMouse
                    name: "x"
                    size: 9
                    strokeWidth: 3
                    color: Colors.settingsBackground
                }
                MouseArea {
                    id: closeMouse
                    anchors.fill: parent
                    anchors.margins: -4
                    hoverEnabled: true
                    onClicked: Ui.settingsOpen = false
                }
            }

            SearchField {
                id: search
                anchors {
                    left: parent.left
                    right: parent.right
                    top: parent.top
                    margins: 12
                    topMargin: 42
                }
                placeholder: "Ara"
                onTextChanged: root.query = text
                onMoved: step => root.step(step)
                onAccepted: keys.forceActiveFocus()
            }

            Flickable {
                id: sideList
                anchors {
                    left: parent.left
                    right: parent.right
                    top: search.bottom
                    topMargin: 10
                    bottom: parent.bottom
                }
                contentHeight: sideColumn.implicitHeight + 12
                boundsBehavior: Flickable.StopAtBounds
                clip: true

                Column {
                    id: sideColumn
                    x: 8
                    width: sideList.width - 16

                    Repeater {
                        model: root.shownSections

                        Item {
                            id: entry

                            required property var modelData
                            required property int index
                            readonly property bool selected: modelData.id === root.page
                            // Gruplar arasında boşluk (aramadayken yok)
                            readonly property bool groupStart: root.query === "" && index > 0 && root.shownSections[index - 1].group !== modelData.group

                            width: sideColumn.width
                            height: 34 + (groupStart ? 12 : 0)

                            Rectangle {
                                anchors {
                                    left: parent.left
                                    right: parent.right
                                    bottom: parent.bottom
                                }
                                height: 34
                                radius: 8
                                color: entry.selected ? Colors.sidebarSelected : entryMouse.containsMouse ? Colors.settingsRowHover : "transparent"

                                SectionIcon {
                                    id: entryIcon
                                    anchors {
                                        left: parent.left
                                        leftMargin: 7
                                        verticalCenter: parent.verticalCenter
                                    }
                                    section: entry.modelData.id
                                    icon: entry.modelData.icon
                                    size: 22
                                }
                                Text {
                                    anchors {
                                        left: entryIcon.right
                                        leftMargin: 10
                                        right: parent.right
                                        rightMargin: 8
                                        verticalCenter: parent.verticalCenter
                                    }
                                    text: entry.modelData.title
                                    elide: Text.ElideRight
                                    color: Colors.text
                                    font.family: Typography.family
                                    font.pixelSize: Typography.body - 1
                                    font.weight: entry.selected ? Font.DemiBold : Font.Normal
                                }
                                MouseArea {
                                    id: entryMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onClicked: root.select(entry.modelData.id)
                                }
                            }
                        }
                    }

                    Text {
                        visible: root.shownSections.length === 0
                        width: parent.width
                        topPadding: 8
                        horizontalAlignment: Text.AlignHCenter
                        text: "Sonuç yok"
                        color: Colors.textMuted
                        font.family: Typography.family
                        font.pixelSize: Typography.body - 1
                    }
                }
            }
        }

        // ---------- Sayfa ----------
        Rectangle {
            id: content

            anchors {
                left: sidebar.right
                right: parent.right
                top: parent.top
                bottom: parent.bottom
            }
            color: Colors.settingsBackground

            // Kenar çubuğuyla arasında ince çizgi
            Rectangle {
                width: 1
                height: parent.height
                color: Colors.panelBorder
            }

            // Üst şerit burada da pencereyi taşır
            MouseArea {
                anchors {
                    left: parent.left
                    right: parent.right
                    top: parent.top
                }
                height: 22
                z: 5
                onPressed: root.startSystemMove()
            }

            Loader {
                id: pageLoader

                anchors.fill: parent
                anchors.leftMargin: 1
                sourceComponent: ({
                        appearance: appearancePage,
                        windows: windowsPage,
                        bar: barPage,
                        dock: dockPage,
                        notifications: notificationsPage,
                        display: displayPage,
                        power: powerPage,
                        input: inputPage,
                        screenshot: screenshotPage,
                        shortcuts: shortcutsPage,
                        about: aboutPage
                    })[root.page]

                // Sayfa değişince hafifçe belirir
                onLoaded: {
                    item.opacity = 0;
                    fadeIn.restart();
                }
                NumberAnimation {
                    id: fadeIn
                    target: pageLoader.item
                    property: "opacity"
                    to: 1
                    duration: Metrics.durationNormal
                    easing.type: Easing.OutCubic
                }
            }
        }

    }

    Component {
        id: appearancePage
        AppearancePage {}
    }
    Component {
        id: windowsPage
        WindowsPage {}
    }
    Component {
        id: barPage
        BarPage {}
    }
    Component {
        id: dockPage
        DockPage {}
    }
    Component {
        id: notificationsPage
        NotificationsPage {}
    }
    Component {
        id: displayPage
        DisplayPage {}
    }
    Component {
        id: powerPage
        PowerPage {}
    }
    Component {
        id: inputPage
        InputPage {}
    }
    Component {
        id: screenshotPage
        ScreenshotPage {}
    }
    Component {
        id: shortcutsPage
        ShortcutsPage {}
    }
    Component {
        id: aboutPage
        AboutPage {}
    }
}
