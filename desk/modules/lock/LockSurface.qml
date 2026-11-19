import QtQuick
import Quickshell.Wayland
import qs.theme

// Kilitli ekranın yüzeyi (her ekrana bir tane); içerik LockContent.qml'de
WlSessionLockSurface {
    id: root

    required property var lock   // LockScreen.qml

    color: Colors.lockFallback

    LockContent {
        anchors.fill: parent
        lock: root.lock
    }
}
