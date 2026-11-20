import QtQuick
import qs.theme
import qs.components

// Bölümün renkli kare simgesi (kenar çubuğunda ve sayfa başlarında)
Rectangle {
    id: root

    property string section
    property string icon
    property real size: 24

    implicitWidth: size
    implicitHeight: size
    radius: Math.round(size * 0.27)
    // Üstten hafif aydınlık (macOS'taki simgeler gibi)
    gradient: Gradient {
        GradientStop {
            position: 0
            color: Colors.settingsSectionColor(root.section, true)
        }
        GradientStop {
            position: 1
            color: Colors.settingsSectionColor(root.section, false)
        }
    }

    Icon {
        anchors.centerIn: parent
        name: root.icon
        size: root.size * 0.62
        strokeWidth: 2.2
        color: Colors.settingsSectionIcon
    }
}
