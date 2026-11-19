import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Hyprland
import Quickshell.Widgets
import qs.theme
import qs.components
import qs.services

// Ada (çentik).
// Kapalı: çalışma alanı noktaları ve düzen adı. Müzik çalıyorsa yanlarda küçük kapak ve dalga.
// Açık: müzik çalarken üstüne gelince kapak, şarkı, ilerleme ve düğmeler.
// Bar penceresi zaten büyük; yalnızca siyah şekil büyüyüp küçülür (plan: Sorun 12).
Item {
    id: root

    // Bar.qml tıklama maskesine bu şekli ekler
    readonly property alias shape: shape

    readonly property bool music: Media.active
    property bool expanded: false

    // Bildirim: adada gösterilen (Notifications.current). Müziğin önüne geçer.
    readonly property var notice: Notifications.current
    readonly property bool notifying: notice !== null
    // Yanıt yazılıyor (Bar.qml bu sırada klavyeyi adaya verir)
    property bool replying: false
    onNoticeChanged: replying = false

    // Şeklin gideceği ölçüler; oraya yay hareketiyle varır
    property real shapeWidth: notifying ? Metrics.islandNoticeWidth : expanded ? Metrics.islandExpandedWidth : music ? Metrics.islandMusicWidth : Metrics.islandWidth
    property real shapeHeight: notifying ? Metrics.islandNoticeHeight + (replying ? Metrics.islandReplyHeight : 0) : expanded ? Metrics.islandExpandedHeight : Metrics.islandHeight
    property real shapeRadius: notifying || expanded ? Metrics.islandExpandedRadius : Metrics.islandRadius

    Behavior on shapeWidth {
        SpringAnimation {
            spring: Metrics.islandSpring
            damping: Metrics.islandDamping
            epsilon: 0.25
        }
    }
    Behavior on shapeHeight {
        SpringAnimation {
            spring: Metrics.islandSpring
            damping: Metrics.islandDamping
            epsilon: 0.25
        }
    }
    Behavior on shapeRadius {
        SpringAnimation {
            spring: Metrics.islandSpring
            damping: Metrics.islandDamping + 0.05
            epsilon: 0.25
        }
    }

    // 0 = kapalı, 1 = açık. İçerikler buna göre yer değiştirir.
    readonly property real progress: Math.min(1, Math.max(0, (shapeHeight - Metrics.islandHeight) / (Metrics.islandExpandedHeight - Metrics.islandHeight)))

    // Genişlik Bar.qml'den gelir (tam genişlik); şekil ortalanır
    implicitHeight: shapeHeight

    onMusicChanged: {
        if (!music)
            expanded = false;
    }

    // Açıkken şarkının konumu saniyede bir güncellensin
    Binding {
        target: Media
        property: "trackPosition"
        value: true
        when: root.expanded
    }

    // --- Ne zaman açılır, ne zaman kapanır
    // Kapak ya da dalganın üstüne gelince hemen; adanın ortasında kısa bir an bekleyince.
    // Böylece çalışma alanı noktasına hızlıca tıklamak adayı açmaz.
    function expandNow() {
        if (music && !notifying)
            expanded = true;
        collapseTimer.stop();
    }

    // Fare bildirimin üstündeyken ya da yanıt yazılırken bildirim kapanmaz
    Binding {
        target: Notifications
        property: "hold"
        value: shapeHover.hovered || root.replying
        when: root.notifying
    }

    Timer {
        id: dwellTimer
        interval: 250
        onTriggered: root.expandNow()
    }
    Timer {
        id: collapseTimer
        interval: 150
        onTriggered: root.expanded = false
    }

    // --- Çalışma alanları
    readonly property int activeId: WindowManager.workspace?.id ?? 1
    readonly property var ids: {
        const list = [1, 2, 3, 4, 5];
        for (const ws of Hyprland.workspaces.values) {
            if (ws.id > 5 && !list.includes(ws.id))
                list.push(ws.id);
        }
        return list.sort((a, b) => a - b);
    }

    function workspace(id) {
        return Hyprland.workspaces.values.find(ws => ws.id === id) ?? null;
    }

    function activate(id) {
        const ws = workspace(id);
        if (ws)
            ws.activate();
        else
            WindowManager.dispatch(`hl.dsp.focus({ workspace = ${id} })`);
    }

    // --- Açıkken altına düşen gölge (şeklin siyah bir kopyasından)
    Rectangle {
        id: shadowSource
        visible: false
        anchors.horizontalCenter: parent.horizontalCenter
        width: root.shapeWidth
        height: root.shapeHeight
        color: "black"
        bottomLeftRadius: root.shapeRadius
        bottomRightRadius: root.shapeRadius
    }

    MultiEffect {
        source: shadowSource
        anchors.fill: shadowSource
        visible: root.progress > 0.01
        opacity: root.progress
        autoPaddingEnabled: true
        shadowEnabled: true
        shadowColor: "black"
        shadowOpacity: 0.55
        shadowBlur: 1.0
        blurMax: 40
        shadowVerticalOffset: 14
    }

    // --- Şeklin kendisi: içerik köşelerden taşmasın diye kırpılır
    ClippingRectangle {
        id: shape

        anchors.horizontalCenter: parent.horizontalCenter
        width: root.shapeWidth
        height: root.shapeHeight
        color: Colors.island
        topLeftRadius: 0
        topRightRadius: 0
        bottomLeftRadius: root.shapeRadius
        bottomRightRadius: root.shapeRadius

        HoverHandler {
            id: shapeHover
            onHoveredChanged: {
                if (hovered) {
                    collapseTimer.stop();
                    if (root.music && !root.expanded)
                        dwellTimer.restart();
                } else {
                    dwellTimer.stop();
                    if (root.expanded)
                        collapseTimer.restart();
                }
            }
        }

        // ---------- Kapalı hâl ----------
        Item {
            id: collapsedView

            anchors {
                top: parent.top
                left: parent.left
                right: parent.right
            }
            height: Metrics.islandHeight
            opacity: Math.max(0, 1 - root.progress * 4)
            visible: opacity > 0

            // Müzik: solda küçük kapak
            AlbumArt {
                anchors {
                    left: parent.left
                    leftMargin: 8
                    verticalCenter: parent.verticalCenter
                }
                visible: root.music
                size: 20
                source: Media.artUrl

                HoverHandler {
                    onHoveredChanged: {
                        if (hovered)
                            root.expandNow();
                    }
                }
            }

            RowLayout {
                anchors.centerIn: parent
                spacing: 14

                // Çalışma alanı noktaları: etkin alan vurgu renginde uzun hap,
                // penceresi olan alan açık, boş alan soluk
                Row {
                    spacing: 6

                    // ScriptModel: alan açılıp kapanınca noktalar baştan kurulmaz,
                    // böylece etkin noktanın kayma animasyonu kesilmez
                    Repeater {
                        model: ScriptModel {
                            values: root.ids
                        }

                        delegate: Rectangle {
                            id: dot

                            required property int modelData
                            readonly property var ws: root.workspace(modelData)
                            readonly property bool isActive: modelData === root.activeId
                            readonly property bool occupied: (ws?.toplevels?.values?.length ?? 0) > 0

                            anchors.verticalCenter: parent.verticalCenter
                            width: isActive ? 18 : 6
                            height: 6
                            radius: 3
                            color: isActive ? Colors.accent : occupied ? Colors.islandDot : Colors.islandDotEmpty

                            Behavior on width {
                                NumberAnimation {
                                    duration: Metrics.durationDot
                                    easing.type: Easing.OutCubic
                                }
                            }
                            Behavior on color {
                                ColorAnimation { duration: Metrics.durationDot }
                            }

                            // Küçük noktalara tıklamak kolay olsun diye tıklama alanı geniş;
                            // yanlarda en fazla aradaki boşluğun yarısı kadar, komşuyla çakışmasın
                            MouseArea {
                                anchors {
                                    fill: parent
                                    leftMargin: -3
                                    rightMargin: -3
                                    topMargin: -10
                                    bottomMargin: -10
                                }
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.activate(dot.modelData)
                            }
                        }
                    }
                }

                // Düzen simgesi ve adı
                Row {
                    spacing: 6

                    LayoutIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        layout: WindowManager.layout
                        size: 14
                        color: Colors.islandText
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: WindowManager.layout
                        color: Colors.islandText
                        font.family: Typography.family
                        font.pixelSize: Typography.small
                        font.weight: Font.Medium
                    }
                }
            }

            // Müzik: sağda dalga
            Wave {
                anchors {
                    right: parent.right
                    rightMargin: 14
                    verticalCenter: parent.verticalCenter
                }
                visible: root.music
                bars: 4
                maxHeight: 13
                playing: Media.playing

                HoverHandler {
                    onHoveredChanged: {
                        if (hovered)
                            root.expandNow();
                    }
                }
            }
        }

        // ---------- Açık hâl: müzik ----------
        // Tam boyutta durur; şekil büyüdükçe ortadan dışa doğru görünür olur
        Item {
            id: expandedView

            anchors {
                top: parent.top
                horizontalCenter: parent.horizontalCenter
            }
            width: Metrics.islandExpandedWidth
            height: Metrics.islandExpandedHeight
            opacity: root.notifying ? 0 : Math.min(1, Math.max(0, (root.progress - 0.3) / 0.45))
            visible: opacity > 0

            RowLayout {
                anchors {
                    fill: parent
                    leftMargin: 18
                    rightMargin: 24
                    topMargin: 18
                    bottomMargin: 18
                }
                spacing: 18

                // Kapak: tıklayınca oynatıcının penceresi öne gelir
                AlbumArt {
                    size: 80
                    source: Media.artUrl

                    TapHandler {
                        onTapped: Media.raise()
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 12

                        Text {
                            Layout.fillWidth: true
                            text: Media.title
                            color: Colors.islandProgress
                            font.family: Typography.family
                            font.pixelSize: 15
                            font.weight: Font.DemiBold
                            elide: Text.ElideRight
                        }

                        Wave {
                            bars: 5
                            maxHeight: 16
                            playing: Media.playing
                        }
                    }

                    Text {
                        Layout.fillWidth: true
                        text: [Media.artist, Media.source].filter(s => s !== "").join(" · ")
                        color: Colors.islandMuted
                        font.family: Typography.family
                        font.pixelSize: Typography.small
                        elide: Text.ElideRight
                    }

                    // İlerleme çubuğu: tıklanan yere atlar (oynatıcı izin veriyorsa)
                    Item {
                        Layout.fillWidth: true
                        Layout.topMargin: 6
                        implicitHeight: 4
                        visible: Media.hasPosition

                        Rectangle {
                            anchors.fill: parent
                            radius: 2
                            color: Colors.islandTrack
                        }
                        Rectangle {
                            height: parent.height
                            width: parent.width * Math.min(1, Media.position / Media.length)
                            radius: 2
                            color: Colors.islandProgress
                        }
                        MouseArea {
                            anchors {
                                fill: parent
                                topMargin: -6
                                bottomMargin: -6
                            }
                            enabled: Media.canSeek
                            cursorShape: Qt.PointingHandCursor
                            onClicked: mouse => Media.seek(mouse.x / width)
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        visible: Media.hasPosition

                        Text {
                            text: Media.formatTime(Media.position)
                            color: Colors.islandFaint
                            font.family: Typography.family
                            font.pixelSize: 11
                            font.features: {
                                "tnum": 1
                            }
                        }
                        Item {
                            Layout.fillWidth: true
                        }
                        Text {
                            text: "-" + Media.formatTime(Media.length - Media.position)
                            color: Colors.islandFaint
                            font.family: Typography.family
                            font.pixelSize: 11
                            font.features: {
                                "tnum": 1
                            }
                        }
                    }
                }

                // Önceki, oynat/duraklat, sonraki
                Row {
                    spacing: 6

                    ControlButton {
                        anchors.verticalCenter: parent.verticalCenter
                        icon: "skip-back"
                        onClicked: Media.previous()
                    }
                    ControlButton {
                        anchors.verticalCenter: parent.verticalCenter
                        icon: Media.playing ? "pause" : "play"
                        size: 44
                        iconSize: 20
                        filled: true
                        onClicked: Media.togglePlaying()
                    }
                    ControlButton {
                        anchors.verticalCenter: parent.verticalCenter
                        icon: "skip-forward"
                        onClicked: Media.next()
                    }
                }
            }
        }

        // ---------- Açık hâl: bildirim ----------
        IslandNotice {
            anchors {
                top: parent.top
                horizontalCenter: parent.horizontalCenter
            }
            island: root
            opacity: root.notifying ? Math.min(1, Math.max(0, (root.progress - 0.3) / 0.45)) : 0
            visible: opacity > 0
        }
    }

    // Yuvarlak oynatma düğmesi
    component ControlButton: Rectangle {
        id: button

        property string icon
        property real size: 38
        property real iconSize: 19
        property bool filled: false
        signal clicked

        width: size
        height: size
        radius: size / 2
        color: filled ? Colors.islandButton : buttonMouse.containsMouse ? Colors.islandButtonHover : "transparent"

        Icon {
            anchors.centerIn: parent
            name: button.icon
            size: button.iconSize
            strokeWidth: 2
            color: Colors.islandProgress
            fill: Colors.islandProgress
        }

        MouseArea {
            id: buttonMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: button.clicked()
        }
    }
}
