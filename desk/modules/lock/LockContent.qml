import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import qs.theme
import qs.components
import qs.services

// Kilit ekranının içeriği (maketteki gibi, macOS düzeni). Kilitte LockSurface.qml'in,
// deneme hâlinde (DESK_LOCK_TEST=1) sıradan bir pencerenin içinde durur.
//   üstte tarih ve büyük saat; çalıyorsa altında müzik
//   altta kişi, şifre kutusu ve uyarı satırı (Caps Lock, yanlış şifre)
//   sağ üstte klavye düzeni, Wi-Fi, pil; sağ altta uyku, yeniden başlat, kapat
// Arka plan: duvar kâğıdının bulanık, kararmış hâli.
Item {
    id: root

    required property var lock   // LockScreen.qml

    // ---------- Klavye odağı ----------
    // Yazılanlar hep şifre kutusuna gitsin. Uykudan dönünce ya da ekran kapanıp açılınca pencere
    // odağı bir an kaybedip geri alabiliyor; kutu o arada odağını yitirirse tıklamadan yazılamıyordu.
    // Pencere etkinleşince, görününce ve kutu odağı kaybedince odak geri verilir.
    // (Hyprland tarafı: hypr/scripts/idle.sh → resume, wake: imleci kıpırdatıp odağı yeniletir.)
    function focusInput() {
        if (!input.activeFocus)
            input.forceActiveFocus();
    }
    readonly property bool windowActive: Window.active
    onWindowActiveChanged: {
        if (windowActive)
            Qt.callLater(focusInput);
    }
    onVisibleChanged: {
        if (visible)
            Qt.callLater(focusInput);
    }

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    // Kişinin adı (getent'teki tam ad; yoksa kullanıcı adı) ve resmi (~/.face, varsa)
    property bool hasFace: false
    Process {
        command: ["test", "-f", Quickshell.env("HOME") + "/.face"]
        running: true
        onExited: code => root.hasFace = code === 0
    }
    property string userName: {
        const user = Quickshell.env("USER") ?? "";
        return user.charAt(0).toUpperCase() + user.slice(1);
    }
    Process {
        command: ["sh", "-c", "getent passwd \"$USER\" | cut -d: -f5 | cut -d, -f1"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                if (text.trim() !== "")
                    root.userName = text.trim();
            }
        }
    }

    // ---------- Arka plan ----------
    Item {
        id: background
        anchors.fill: parent

        // Küçük çözülüp bulanıklaştırılır: hem hızlı hem yumuşak
        Image {
            id: wallpaper
            anchors.fill: parent
            source: Wallpaper.fileUrl(Wallpaper.current)
            sourceSize: Qt.size(Math.round(root.width / 4), Math.round(root.height / 4))
            fillMode: Image.PreserveAspectCrop
            asynchronous: false // kilit ilk karede hazır olsun
            visible: false
        }
        MultiEffect {
            anchors.fill: parent
            source: wallpaper
            visible: wallpaper.status === Image.Ready
            blurEnabled: true
            blur: 1
            blurMax: 48
            autoPaddingEnabled: false
            saturation: 0.1
        }
        // Karartma duvar kâğıdına göre (Colors.lockDim: açık resimde daha çok).
        // Üst ve alt kenarlar ayrıca koyulaşır: küçük yazılar (durum, ad, uyarı) oralarda.
        // Ölçüler scripts/themelib.py → LOCK_ZONES; bembeyaz duvar kâğıdı contrast.py'de denetlenir.
        Rectangle {
            anchors.fill: parent
            color: Colors.lockShade
        }
        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                GradientStop {
                    position: 0
                    color: Colors.lockEdge
                }
                GradientStop {
                    position: Metrics.lockEdgeTop
                    color: "transparent"
                }
                GradientStop {
                    position: Metrics.lockEdgeBottom
                    color: "transparent"
                }
                GradientStop {
                    position: 1
                    color: Colors.lockEdge
                }
            }
        }
    }

    // Açılırken içerik yumuşakça belirir
    Item {
        id: content
        anchors.fill: parent
        opacity: 0
        Component.onCompleted: opacity = 1

        Behavior on opacity {
            NumberAnimation {
                duration: 260
                easing.type: Easing.OutCubic
            }
        }

        // Deneme hâlinde sol üstte küçük bir not
        Text {
            visible: root.lock.testMode
            anchors {
                top: parent.top
                left: parent.left
                margins: 22
            }
            text: "Deneme: ekran kilitli değil · boşken Esc kapatır"
            color: Colors.lockText
            font.family: Typography.family
            font.pixelSize: 13
        }

        // ---------- Sağ üst: klavye düzeni, Wi-Fi, pil ----------
        RowLayout {
            anchors {
                top: parent.top
                right: parent.right
                margins: 22
            }
            spacing: 16
            layer.enabled: true
            layer.effect: TextShadow {}

            Text {
                text: KeyboardLayout.code
                color: Colors.lockText
                font.family: Typography.family
                font.pixelSize: 14
                font.weight: Font.DemiBold
            }
            WifiIcon {
                visible: NetworkStatus.kind === "wifi"
                strength: NetworkStatus.strength
                size: 17
                color: Colors.lockText
            }
            RowLayout {
                visible: BatteryStatus.present
                spacing: 6

                Text {
                    text: Math.round(BatteryStatus.level * 100) + "%"
                    color: Colors.lockText
                    font.family: Typography.family
                    font.pixelSize: 14
                    font.features: {
                        "tnum": 1
                    }
                }
                BatteryIcon {
                    level: BatteryStatus.level
                    charging: BatteryStatus.charging
                    color: Colors.lockText
                }
            }
        }

        // ---------- Tarih ve saat ----------
        Column {
            id: clockColumn

            anchors.horizontalCenter: parent.horizontalCenter
            y: Math.round(parent.height * 0.12)
            spacing: -6

            layer.enabled: true
            layer.effect: TextShadow {}

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Qt.locale("tr_TR").toString(clock.date, "dddd, d MMMM")
                color: Colors.lockText
                font.family: Typography.family
                font.pixelSize: 26
                font.weight: Font.DemiBold
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Qt.formatTime(clock.date, "HH:mm")
                color: Colors.lockText
                font.family: Typography.family
                font.pixelSize: 150
                font.weight: Font.Bold
                font.features: {
                    "tnum": 1
                }
            }
        }

        // ---------- Müzik (çalıyorsa) ----------
        Rectangle {
            anchors {
                horizontalCenter: parent.horizontalCenter
                top: clockColumn.bottom
                topMargin: 28
            }
            visible: Media.active
            width: Metrics.lockMusicWidth
            height: 76
            radius: 22
            color: Colors.glass
            border.width: 1
            border.color: Colors.panelBorder

            RowLayout {
                anchors {
                    fill: parent
                    margins: 12
                    rightMargin: 16
                }
                spacing: 12

                AlbumArt {
                    source: Media.artUrl
                    size: 52
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 1

                    Text {
                        Layout.fillWidth: true
                        text: Media.title
                        color: Colors.text
                        font.family: Typography.family
                        font.pixelSize: 14
                        font.weight: Font.DemiBold
                        elide: Text.ElideRight
                    }
                    Text {
                        Layout.fillWidth: true
                        visible: text !== ""
                        text: Media.artist
                        color: Colors.textMuted
                        font.family: Typography.family
                        font.pixelSize: 13
                        elide: Text.ElideRight
                    }
                }
                MediaButton {
                    icon: "skip-back"
                    onClicked: Media.previous()
                }
                MediaButton {
                    icon: Media.playing ? "pause" : "play"
                    filled: true
                    onClicked: Media.togglePlaying()
                }
                MediaButton {
                    icon: "skip-forward"
                    onClicked: Media.next()
                }
            }
        }

        // ---------- Kişi ve şifre ----------
        Column {
            anchors.horizontalCenter: parent.horizontalCenter
            y: Math.round(parent.height * Metrics.lockUserTop)
            spacing: 12

            // Resim (~/.face) ya da adın baş harfi
            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                width: 76
                height: 76
                radius: 38
                color: Colors.lockField
                border.width: 1
                border.color: Colors.lockFieldBorder

                Text {
                    anchors.centerIn: parent
                    visible: face.status !== Image.Ready
                    text: root.userName.charAt(0)
                    color: Colors.lockText
                    font.family: Typography.family
                    font.pixelSize: 32
                    font.weight: Font.DemiBold
                }
                ClippingRectangle {
                    anchors.fill: parent
                    radius: 38
                    color: "transparent"
                    visible: face.status === Image.Ready

                    Image {
                        id: face
                        anchors.fill: parent
                        source: root.hasFace ? Wallpaper.fileUrl(Quickshell.env("HOME") + "/.face") : ""
                        sourceSize: Qt.size(152, 152)
                        fillMode: Image.PreserveAspectCrop
                    }
                }
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.userName
                color: Colors.lockText
                font.family: Typography.family
                font.pixelSize: 17
                font.weight: Font.DemiBold
            }

            // Şifre kutusu: yazılanlar nokta olarak; Enter ya da ok doğrular
            Rectangle {
                id: field

                anchors.horizontalCenter: parent.horizontalCenter
                width: Metrics.lockFieldWidth
                height: 40
                radius: 20
                color: Colors.lockField
                border.width: 1
                border.color: root.lock.failure !== "" ? Colors.lockError : Colors.lockFieldBorder

                // Yanlış şifrede sağa sola sallanır
                property real shift: 0
                transform: Translate {
                    x: field.shift
                }
                SequentialAnimation {
                    id: shakeAnimation
                    loops: 1
                    NumberAnimation {
                        target: field
                        property: "shift"
                        to: -10
                        duration: 50
                    }
                    NumberAnimation {
                        target: field
                        property: "shift"
                        to: 10
                        duration: 70
                    }
                    NumberAnimation {
                        target: field
                        property: "shift"
                        to: -6
                        duration: 70
                    }
                    NumberAnimation {
                        target: field
                        property: "shift"
                        to: 0
                        duration: 60
                    }
                }
                Connections {
                    target: root.lock
                    function onShakeChanged() {
                        shakeAnimation.restart();
                    }
                }

                TextInput {
                    id: input

                    anchors {
                        fill: parent
                        leftMargin: 18
                        rightMargin: 44
                    }
                    verticalAlignment: TextInput.AlignVCenter
                    // Gerçek yazı görünmez; noktaları aşağıdaki satır çizer (boyutu sabit, ortalı değil)
                    color: "transparent"
                    selectionColor: "transparent"
                    selectedTextColor: "transparent"
                    cursorDelegate: Item {} // imleç yok: noktaları aşağıdaki satır çiziyor
                    echoMode: TextInput.Password
                    font.pixelSize: 15
                    focus: true
                    // Doğrulanırken yazı değişmez ama odak kutuda kalır (enabled: false odağı düşürürdü)
                    readOnly: root.lock.busy
                    text: root.lock.password
                    onActiveFocusChanged: {
                        if (!activeFocus && root.windowActive)
                            Qt.callLater(root.focusInput);
                    }
                    onTextEdited: {
                        root.lock.password = text;
                        if (root.lock.failure === "wrong")
                            root.lock.failure = "";
                    }

                    Keys.onPressed: event => {
                        if (event.key === Qt.Key_CapsLock) {
                            capsTimer.restart();
                        } else if (event.key === Qt.Key_Escape) {
                            if (root.lock.busy) {
                                event.accepted = true;
                                return;
                            }
                            if (root.lock.password === "")
                                root.lock.cancel();
                            root.lock.password = "";
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                            root.lock.submit();
                            event.accepted = true;
                        }
                    }
                    Keys.onReleased: event => {
                        if (event.key === Qt.Key_CapsLock)
                            capsTimer.restart();
                    }
                }

                // Noktalar (en çok kutuya sığan kadar)
                Row {
                    anchors {
                        left: parent.left
                        leftMargin: 18
                        verticalCenter: parent.verticalCenter
                    }
                    spacing: 7
                    visible: !root.lock.busy

                    Repeater {
                        model: Math.min(root.lock.password.length, 18)

                        Rectangle {
                            width: 9
                            height: 9
                            radius: 4.5
                            color: Colors.lockText
                        }
                    }
                }
                Text {
                    anchors {
                        left: parent.left
                        leftMargin: 18
                        verticalCenter: parent.verticalCenter
                    }
                    visible: root.lock.password === "" && !root.lock.busy
                    text: "Şifre"
                    color: Colors.lockFaint
                    font.family: Typography.family
                    font.pixelSize: 14
                }
                // Doğrulanırken üç nokta yanıp söner
                Row {
                    anchors.centerIn: parent
                    spacing: 8
                    visible: root.lock.busy

                    Repeater {
                        model: 3

                        Rectangle {
                            id: dot
                            required property int index
                            width: 8
                            height: 8
                            radius: 4
                            color: Colors.lockText
                            opacity: 0.3

                            SequentialAnimation on opacity {
                                running: root.lock.busy
                                loops: Animation.Infinite
                                PauseAnimation {
                                    duration: dot.index * 150
                                }
                                NumberAnimation {
                                    to: 1
                                    duration: 300
                                }
                                NumberAnimation {
                                    to: 0.3
                                    duration: 300
                                }
                                PauseAnimation {
                                    duration: (2 - dot.index) * 150
                                }
                            }
                        }
                    }
                }

                // Ok: doğrula
                Rectangle {
                    anchors {
                        right: parent.right
                        rightMargin: 5
                        verticalCenter: parent.verticalCenter
                    }
                    visible: root.lock.password !== "" && !root.lock.busy
                    width: 30
                    height: 30
                    radius: 15
                    color: submitMouse.containsMouse ? Colors.lockButtonHover : Colors.lockButton

                    Icon {
                        anchors.centerIn: parent
                        name: "chevron-right"
                        size: 16
                        strokeWidth: 2.6
                        color: Colors.lockText
                    }
                    MouseArea {
                        id: submitMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.lock.submit()
                    }
                }
                // Kutuya tıklanınca yazı yeniden buraya
                MouseArea {
                    anchors.fill: parent
                    z: -1
                    onClicked: input.forceActiveFocus()
                }
            }

            // Uyarı satırı: yanlış şifre > Caps Lock (kutunun kırmızı kenarı ve sallanması da söyler)
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                height: 18
                text: root.lock.failure !== "" ? root.lock.failureText : KeyboardLayout.capsLock ? "Caps Lock açık" : ""
                color: Colors.lockText
                font.family: Typography.family
                font.pixelSize: 13
                font.weight: Font.Medium
                layer.enabled: text !== ""
                layer.effect: TextShadow {}
            }
        }

        // ---------- Sağ alt: uyku, yeniden başlat, kapat ----------
        // Yeniden başlat ve kapat iki kez basınca olur (yanlışlıkla basılmasın)
        RowLayout {
            anchors {
                right: parent.right
                bottom: parent.bottom
                margins: 30
            }
            spacing: 22

            PowerButton {
                icon: "moon"
                label: "Uyku"
                onConfirmed: Quickshell.execDetached(["systemctl", "suspend"])
            }
            PowerButton {
                icon: "rotate-ccw"
                label: "Yeniden başlat"
                needsConfirm: true
                onConfirmed: Quickshell.execDetached(["systemctl", "reboot"])
            }
            PowerButton {
                icon: "power"
                label: "Kapat"
                needsConfirm: true
                onConfirmed: Quickshell.execDetached(["systemctl", "poweroff"])
            }
        }
    }

    // Caps Lock tuşundan hemen sonra durumu sor (Hyprland ışığı tuştan sonra değiştiriyor)
    Timer {
        id: capsTimer
        interval: 80
        onTriggered: KeyboardLayout.refresh()
    }
    Component.onCompleted: {
        KeyboardLayout.refresh();
        Qt.callLater(focusInput);
    }

    // Duvar kâğıdının üstündeki yazılara hafif gölge
    component TextShadow: MultiEffect {
        shadowEnabled: true
        shadowColor: Colors.lockShadow
        shadowBlur: 0.7
        shadowVerticalOffset: 1
    }

    component MediaButton: Rectangle {
        id: mediaButton

        property string icon
        property bool filled: false
        signal clicked

        implicitWidth: 32
        implicitHeight: 32
        radius: 16
        color: mediaMouse.containsMouse ? Colors.hover : "transparent"

        Icon {
            anchors.centerIn: parent
            name: mediaButton.icon
            size: mediaButton.filled ? 20 : 17
            color: Colors.text
            fill: mediaButton.filled ? Colors.text : "transparent"
        }
        MouseArea {
            id: mediaMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: mediaButton.clicked()
        }
    }

    component PowerButton: ColumnLayout {
        id: powerButton

        property string icon
        property string label
        property bool needsConfirm: false
        property bool armed: false
        signal confirmed

        spacing: 6

        Timer {
            id: disarm
            interval: 4000
            onTriggered: powerButton.armed = false
        }

        Rectangle {
            Layout.alignment: Qt.AlignHCenter
            implicitWidth: 44
            implicitHeight: 44
            radius: 22
            color: powerButton.armed ? Colors.lockError : powerMouse.containsMouse ? Colors.lockButtonHover : Colors.lockButton

            Icon {
                anchors.centerIn: parent
                name: powerButton.icon
                size: 19
                color: Colors.lockText
            }
            MouseArea {
                id: powerMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (!powerButton.needsConfirm || powerButton.armed) {
                        powerButton.armed = false;
                        powerButton.confirmed();
                    } else {
                        powerButton.armed = true;
                        disarm.restart();
                    }
                }
            }
        }
        Text {
            Layout.alignment: Qt.AlignHCenter
            text: powerButton.armed ? "Tekrar bas" : powerButton.label
            color: Colors.lockMuted
            font.family: Typography.family
            font.pixelSize: 12
        }
    }
}
