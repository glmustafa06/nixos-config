import QtQuick
import Quickshell
import Quickshell.Widgets
import qs.theme
import qs.services
import qs.settings

// Dock'taki tek öğe: uygulama simgesi, İndirilenler, çöp kutusu ya da ayırıcı çizgi.
// Anahtarlar DockApps'tekiler; "sep:…" ayırıcı, "place:downloads" ve "place:trash" yerler.
// Sol tuşla sürüklenince sıralama başlar (Dock.qml: beginDrag); sürüklenirken yeri boş görünür.
Item {
    id: root

    required property string modelData
    required property var dock            // Dock.qml: menü ve ad etiketi

    readonly property string key: modelData
    readonly property bool separator: key.startsWith("sep:")
    readonly property bool place: key.startsWith("place:")

    readonly property var windows: separator || place ? [] : DockApps.windowsOf(key)
    readonly property bool running: windows.length > 0
    // Odaktaki pencere bu uygulamanın mı (noktası vurgu renginde, uzun)
    readonly property bool focused: running && windows.includes(WindowManager.window)

    // Sürükleniyor (yeri boş kalır, simgeyi dock'un "ghost"u çizer)
    readonly property bool dragged: dock.dragKey !== "" && dock.dragKey === key
    // Üstünde dosya sürükleniyor ve bu öğe kabul ediyor
    readonly property bool dropTarget: dock.dropKey !== "" && dock.dropKey === key
    // Görülmemiş bildirim sayısı (köşedeki kırmızı rozet)
    readonly property int badge: separator || place || !Settings.s.dock.badges ? 0 : (Notifications.badges[key] ?? 0)

    // Ad etiketinde görünen ad
    readonly property string title: {
        if (key === "place:downloads")
            return "İndirilenler";
        if (key === "place:trash")
            return Trash.full ? "Çöp kutusu" : "Çöp kutusu (boş)";
        return DockApps.nameOf(key);
    }

    readonly property string iconSource: {
        if (key === "place:downloads")
            return Quickshell.iconPath("folder-download", true);
        if (key === "place:trash")
            return Quickshell.iconPath(Trash.full ? "user-trash-full" : "user-trash", true);
        return separator ? "" : DockApps.iconOf(key);
    }

    // Başlatılıyor: penceresi gelene kadar (en fazla 6 sn) simge yavaşça solup parlar
    property bool launching: false
    onRunningChanged: {
        if (running)
            launching = false;
    }

    implicitWidth: separator ? Metrics.dockSeparatorWidth : Metrics.dockIconSize
    implicitHeight: Metrics.dockIconSize
    opacity: dragged ? 0 : 1

    Component.onDestruction: {
        if (dragged && !dock.dragSettling)
            dock.cancelDrag();
    }

    function startLaunching() {
        launching = true;
        launchTimer.restart();
    }

    function activate() {
        if (key === "place:downloads") {
            dock.showMenu(key, root);
            return;
        }
        dock.closeMenus();
        if (key === "place:trash") {
            Trash.open();
            return;
        }
        if (DockApps.activate(key))
            startLaunching();
    }

    Timer {
        id: launchTimer
        interval: 6000
        onTriggered: root.launching = false
    }

    // Ayırıcı: ince dikey çizgi
    Rectangle {
        visible: root.separator
        anchors.centerIn: parent
        width: 1
        height: parent.height * 0.62
        color: Colors.dockSeparator
    }

    // Üstüne gelince simgenin arkası hafifçe aydınlanır
    Rectangle {
        visible: !root.separator
        anchors {
            fill: parent
            margins: -3
        }
        radius: 12
        color: {
            if (root.dropTarget)
                return Colors.dockDropTarget;
            return mouse.containsMouse && root.dock.dragKey === "" || root.dock.menuKeyOpen === root.key ? Colors.dockHover : "transparent";
        }

        Behavior on color {
            ColorAnimation { duration: Metrics.durationFast }
        }
    }

    IconImage {
        id: icon

        visible: !root.separator
        anchors.centerIn: parent
        implicitSize: Metrics.dockIconSize
        source: root.iconSource
        // Basınca hafifçe içeri çöker; üstüne dosya getirilince büyür
        scale: root.dropTarget ? 1.1 : mouse.pressed && root.dock.dragKey === "" ? 0.9 : 1

        Behavior on scale {
            NumberAnimation {
                duration: 90
                easing.type: Easing.OutCubic
            }
        }
    }

    SequentialAnimation {
        running: root.launching
        loops: Animation.Infinite
        onRunningChanged: {
            if (!running)
                icon.opacity = 1;
        }

        NumberAnimation {
            target: icon
            property: "opacity"
            to: 0.45
            duration: 450
            easing.type: Easing.InOutSine
        }
        NumberAnimation {
            target: icon
            property: "opacity"
            to: 1
            duration: 450
            easing.type: Easing.InOutSine
        }
    }

    // Açık uygulamanın noktası (simgenin altında). Odaktaki uygulamanınki vurgu renginde kısa bir hap.
    Rectangle {
        visible: root.running && Settings.s.dock.indicators
        anchors {
            horizontalCenter: parent.horizontalCenter
            top: parent.bottom
            topMargin: 2
        }
        width: root.focused ? 12 : 4
        height: 4
        radius: 2
        color: root.focused ? Colors.dockIndicatorFocused : Colors.dockIndicator

        Behavior on width {
            NumberAnimation {
                duration: Metrics.durationDot
                easing.type: Easing.OutCubic
            }
        }
        Behavior on color {
            ColorAnimation { duration: Metrics.durationDot }
        }
    }

    // Rozet: görülmemiş bildirim sayısı. Belirirken küçükten büyür.
    Rectangle {
        anchors {
            top: parent.top
            right: parent.right
            topMargin: -4
            rightMargin: -5
        }
        width: Math.max(height, badgeText.implicitWidth + 10)
        height: 19
        radius: height / 2
        color: Colors.badge
        border.width: 1
        border.color: Colors.badgeBorder
        scale: root.badge > 0 ? 1 : 0
        visible: scale > 0

        Behavior on scale {
            NumberAnimation {
                duration: Metrics.durationNormal
                easing.type: Easing.OutBack
            }
        }

        Text {
            id: badgeText
            anchors.centerIn: parent
            // Sayı sıfıra inerken (küçülürken) eski sayı kalsın
            property int shown: 0
            text: shown > 99 ? "99+" : shown
            color: Colors.badgeText
            font.family: Typography.family
            font.pixelSize: 11
            font.weight: Font.Bold
            font.features: {
                "tnum": 1
            }

            Connections {
                target: root
                function onBadgeChanged() {
                    if (root.badge > 0)
                        badgeText.shown = root.badge;
                }
            }
            Component.onCompleted: shown = root.badge
        }
    }

    MouseArea {
        id: mouse

        // Sol tuşla basılıp 8 pikselden fazla kaydırılınca sürükleme başlar
        property point pressPoint
        property bool dragging: false
        property bool suppressClick: false  // sürükleme bitti: ardından gelen tıklama sayılmaz

        anchors.fill: parent
        enabled: !root.separator
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        cursorShape: dragging ? Qt.ClosedHandCursor : Qt.PointingHandCursor

        onContainsMouseChanged: {
            root.dock.hoverItem(root, containsMouse);
            // İndirilenler menüsü açılmadan listeyi hazırla
            if (containsMouse && root.key === "place:downloads")
                Downloads.refresh();
        }
        onPressed: mouse => {
            pressPoint = Qt.point(mouse.x, mouse.y);
            dragging = false;
            suppressClick = false;
        }
        onPositionChanged: mouse => {
            if (!(mouse.buttons & Qt.LeftButton))
                return;
            if (!dragging) {
                if (Math.hypot(mouse.x - pressPoint.x, mouse.y - pressPoint.y) < 8)
                    return;
                dragging = root.dock.beginDrag(root, mouse.x, mouse.y);
            }
            if (dragging)
                root.dock.moveDrag(root, mouse.x, mouse.y);
        }
        onReleased: mouse => {
            if (dragging && mouse.button === Qt.LeftButton) {
                root.dock.endDrag();
                dragging = false;
                suppressClick = true;
            }
        }
        onCanceled: {
            if (dragging)
                root.dock.endDrag();
            dragging = false;
        }
        onClicked: mouse => {
            if (suppressClick) {
                suppressClick = false;
                return;
            }
            if (mouse.button === Qt.RightButton) {
                root.dock.showMenu(root.key, root);
            } else if (mouse.button === Qt.MiddleButton && !root.place) {
                // Orta tık: her zaman yeni pencere
                root.dock.closeMenus();
                DockApps.launch(root.key);
            } else {
                root.activate();
            }
        }
    }
}
