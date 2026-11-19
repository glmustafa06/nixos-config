import QtQuick
import Quickshell
import Quickshell.Widgets
import qs.theme
import qs.services

// Dock'taki tek öğe: uygulama simgesi, İndirilenler, çöp kutusu ya da ayırıcı çizgi.
// Anahtarlar DockApps'tekiler; "sep:…" ayırıcı, "place:downloads" ve "place:trash" yerler.
Item {
    id: root

    required property string modelData
    required property var dock            // Dock.qml: menü ve ad etiketi

    readonly property string key: modelData
    readonly property bool separator: key.startsWith("sep:")
    readonly property bool place: key.startsWith("place:")

    readonly property var windows: separator || place ? [] : DockApps.windowsOf(key)
    readonly property bool running: windows.length > 0

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

    implicitWidth: separator ? 13 : Metrics.dockIconSize
    implicitHeight: Metrics.dockIconSize

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
        if (DockApps.activate(key)) {
            launching = true;
            launchTimer.restart();
        }
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
        color: mouse.containsMouse || root.dock.menuKeyOpen === root.key ? Colors.dockHover : "transparent"

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
        // Basınca hafifçe içeri çöker
        scale: mouse.pressed ? 0.9 : 1

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

    // Açık uygulamanın noktası (simgenin altında)
    Rectangle {
        visible: root.running
        anchors {
            horizontalCenter: parent.horizontalCenter
            top: parent.bottom
            topMargin: 2
        }
        width: 4
        height: 4
        radius: 2
        color: Colors.dockIndicator
    }

    MouseArea {
        id: mouse

        anchors.fill: parent
        enabled: !root.separator
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        cursorShape: Qt.PointingHandCursor

        onContainsMouseChanged: {
            root.dock.hoverItem(root, containsMouse);
            // İndirilenler menüsü açılmadan listeyi hazırla
            if (containsMouse && root.key === "place:downloads")
                Downloads.refresh();
        }
        onClicked: mouse => {
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
