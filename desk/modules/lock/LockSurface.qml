import QtQuick
import Quickshell.Wayland
import qs.theme

// Kilitli ekranın yüzeyi (her ekrana bir tane); içerik LockContent.qml'de
WlSessionLockSurface {
    id: root

    required property var lock   // LockScreen.qml

    color: Colors.lockFallback

    LockContent {
        id: content
        anchors.fill: parent
        lock: root.lock
    }

    // Yüzey yeniden görünür olunca (ekran yeniden bağlandı, uykudan dönüldü) yazı şifre kutusuna
    onVisibleChanged: {
        if (visible)
            Qt.callLater(content.focusInput);
    }
}
