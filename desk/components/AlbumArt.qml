import QtQuick
import Quickshell.Widgets
import qs.theme

// Yuvarlak köşeli kapak resmi. Resim yoksa ya da yüklenemezse koyu zemin ve nota simgesi.
ClippingRectangle {
    id: root

    property string source: ""
    property real size: 20

    implicitWidth: size
    implicitHeight: size
    radius: size / 4.6 // tasarımdaki oran: 80 px'te 17 px
    color: Colors.albumPlaceholder

    Icon {
        anchors.centerIn: parent
        visible: image.status !== Image.Ready
        name: "music"
        size: root.size * 0.5
        strokeWidth: 2
        color: Colors.islandMuted
    }

    Image {
        id: image
        anchors.fill: parent
        source: root.source
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: true
        // Ekrandaki boyutun iki katı: keskin dursun ama büyük resimler belleği doldurmasın
        sourceSize.width: root.size * 2
        sourceSize.height: root.size * 2
        visible: status === Image.Ready
    }
}
