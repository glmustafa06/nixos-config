import QtQuick
import QtQuick.Layouts
import QtQuick.Effects

// desk'in giriş ekranı (SDDM, Qt 6). Kilit ekranıyla aynı (desk/modules/lock/LockContent.qml):
//   üstte tarih ve büyük saat, altta kişi ve şifre kutusu, sağ altta uyku/yeniden başlat/kapat,
//   sol altta oturum seçici (Hyprland (UWSM) …), sağ üstte klavye düzeni.
// Arka plan: desk'in duvar kâğıdının bulanık, karartılmış hâli (/var/lib/desk/login.jpg,
// scripts/login_screen.py). SDDM'in verdikleri: sddm, userModel, sessionModel, keyboard, config.
Rectangle {
    id: root

    width: 1920
    height: 1080
    color: config.background || "#14171b"

    readonly property string shared: "file://" + (config.shared || "/var/lib/desk")
    readonly property var turkish: Qt.locale("tr_TR")

    // Renkler: desk/theme/Colors.qml'deki kilit renkleri
    readonly property color textColor: "#ffffff"
    readonly property color mutedColor: Qt.rgba(1, 1, 1, 0.82)
    readonly property color faintColor: Qt.rgba(1, 1, 1, 0.62)
    readonly property color shadowColor: Qt.rgba(0, 0, 0, 0.45)
    readonly property color fieldColor: Qt.rgba(1, 1, 1, 0.16)
    readonly property color fieldBorder: Qt.rgba(1, 1, 1, 0.22)
    readonly property color buttonColor: Qt.rgba(1, 1, 1, 0.14)
    readonly property color buttonHover: Qt.rgba(1, 1, 1, 0.24)
    readonly property color errorColor: "#e5484d"
    readonly property color menuColor: Qt.rgba(30 / 255, 32 / 255, 36 / 255, 0.92)
    readonly property string fontFamily: "Inter"

    // ---------- Durum ----------
    property string password: ""
    property bool busy: false
    property string failure: ""
    property int shakes: 0
    property var now: new Date()

    // Kullanıcılar ve oturumlar (SDDM'in modellerinden düz listeye)
    property var users: []
    property var sessions: []
    property int userIndex: 0
    property int sessionIndex: sessionModel.lastIndex >= 0 ? sessionModel.lastIndex : 0
    readonly property var user: users.length > 0 ? users[Math.min(userIndex, users.length - 1)] : ({
            name: userModel.lastUser,
            realName: ""
        })
    readonly property string displayName: {
        const real = (user.realName ?? "").split(",")[0].trim();
        const name = user.name ?? "";
        return real !== "" ? real : name.charAt(0).toUpperCase() + name.slice(1);
    }

    function submit() {
        if (busy || password === "")
            return;
        busy = true;
        failure = "";
        sddm.login(user.name, password, sessionIndex);
    }

    Connections {
        target: sddm
        function onLoginFailed() {
            root.busy = false;
            root.failure = "Şifre yanlış";
            root.password = "";
            root.shakes++;
            input.forceActiveFocus();
        }
        function onLoginSucceeded() {
            root.busy = true;
        }
    }

    Repeater {
        model: userModel
        delegate: Item {
            Component.onCompleted: {
                const list = root.users.slice();
                list[index] = {
                    name: model.name,
                    realName: model.realName ?? ""
                };
                root.users = list;
                if (model.name === userModel.lastUser)
                    root.userIndex = index;
            }
        }
    }
    Repeater {
        model: sessionModel
        delegate: Item {
            Component.onCompleted: {
                const list = root.sessions.slice();
                list[index] = model.name;
                root.sessions = list;
            }
        }
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: root.now = new Date()
    }

    // ---------- Arka plan ----------
    Image {
        id: wallpaper
        anchors.fill: parent
        source: root.shared + "/login.jpg"
        fillMode: Image.PreserveAspectCrop
        smooth: true
        asynchronous: false
        cache: false
    }
    // Duvar kâğıdı yoksa yine de koyu ve sakin
    Rectangle {
        anchors.fill: parent
        visible: wallpaper.status !== Image.Ready
        gradient: Gradient {
            GradientStop {
                position: 0
                color: "#1d2128"
            }
            GradientStop {
                position: 1
                color: "#101216"
            }
        }
    }
    // Üst ve alt kenar ayrıca koyulaşır (kilitteki gibi: Metrics.lockEdgeTop/Bottom, Colors.lockEdge)
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop {
                position: 0
                color: Qt.rgba(0, 0, 0, 0.40)
            }
            GradientStop {
                position: 0.22
                color: "transparent"
            }
            GradientStop {
                position: 0.50
                color: "transparent"
            }
            GradientStop {
                position: 1
                color: Qt.rgba(0, 0, 0, 0.40)
            }
        }
    }

    // Boş yere tıklayınca oturum listesi kapanır, yazı şifre kutusuna döner
    MouseArea {
        anchors.fill: parent
        onClicked: {
            sessionMenu.visible = false;
            input.forceActiveFocus();
        }
    }

    // ---------- Sağ üst: klavye düzeni ----------
    Text {
        anchors {
            top: parent.top
            right: parent.right
            margins: 22
        }
        visible: text !== ""
        text: {
            const layouts = keyboard.layouts ?? [];
            const current = layouts[keyboard.currentLayout];
            return current ? (current.shortName ?? "").toUpperCase() : "";
        }
        color: root.textColor
        font.family: root.fontFamily
        font.pixelSize: 14
        font.weight: Font.DemiBold
        layer.enabled: true
        layer.effect: TextShadow {}
    }

    // ---------- Tarih ve saat ----------
    Column {
        anchors.horizontalCenter: parent.horizontalCenter
        y: Math.round(parent.height * 0.12)
        spacing: -6
        layer.enabled: true
        layer.effect: TextShadow {}

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.turkish.toString(root.now, "dddd, d MMMM")
            color: root.textColor
            font.family: root.fontFamily
            font.pixelSize: 26
            font.weight: Font.DemiBold
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Qt.formatTime(root.now, "HH:mm")
            color: root.textColor
            font.family: root.fontFamily
            font.pixelSize: 150
            font.weight: Font.Bold
            font.features: {
                "tnum": 1
            }
        }
    }

    // ---------- Kişi ve şifre ----------
    Column {
        anchors.horizontalCenter: parent.horizontalCenter
        y: Math.round(parent.height * 0.70)
        spacing: 12

        // Resim (/var/lib/desk/avatar-<kullanıcı>.png) ya da adın baş harfi
        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            width: 76
            height: 76
            radius: 38
            color: root.fieldColor
            border.width: 1
            border.color: root.fieldBorder

            Text {
                anchors.centerIn: parent
                visible: face.status !== Image.Ready
                text: root.displayName.charAt(0)
                color: root.textColor
                font.family: root.fontFamily
                font.pixelSize: 32
                font.weight: Font.DemiBold
            }
            Image {
                id: face
                anchors.fill: parent
                visible: false
                source: root.user.name ? root.shared + "/avatar-" + root.user.name + ".png" : ""
                sourceSize: Qt.size(152, 152)
                fillMode: Image.PreserveAspectCrop
                cache: false
            }
            // Yuvarlak kırpma
            MultiEffect {
                anchors.fill: parent
                source: face
                visible: face.status === Image.Ready
                maskEnabled: true
                maskSource: faceMask
            }
            Item {
                id: faceMask
                anchors.fill: parent
                visible: false
                layer.enabled: true
                Rectangle {
                    anchors.fill: parent
                    radius: 38
                }
            }
        }

        // Ad; birden çok kullanıcı varsa tıklayınca sıradaki
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.displayName
            color: root.textColor
            font.family: root.fontFamily
            font.pixelSize: 17
            font.weight: Font.DemiBold
            layer.enabled: true
            layer.effect: TextShadow {}

            MouseArea {
                anchors.fill: parent
                enabled: root.users.length > 1
                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                onClicked: {
                    root.userIndex = (root.userIndex + 1) % root.users.length;
                    root.password = "";
                    root.failure = "";
                    input.forceActiveFocus();
                }
            }
        }

        // Şifre kutusu: yazılanlar nokta olarak; Enter ya da ok giriş yapar
        Rectangle {
            id: field

            anchors.horizontalCenter: parent.horizontalCenter
            width: 280
            height: 40
            radius: 20
            color: root.fieldColor
            border.width: 1
            border.color: root.failure !== "" ? root.errorColor : root.fieldBorder

            // Yanlış şifrede sağa sola sallanır
            property real shift: 0
            transform: Translate {
                x: field.shift
            }
            SequentialAnimation {
                id: shake
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
                target: root
                function onShakesChanged() {
                    shake.restart();
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
                // Gerçek yazı görünmez; noktaları aşağıdaki satır çizer
                color: "transparent"
                selectionColor: "transparent"
                selectedTextColor: "transparent"
                cursorDelegate: Item {}
                echoMode: TextInput.Password
                font.pixelSize: 15
                focus: true
                enabled: !root.busy
                text: root.password
                onTextEdited: {
                    root.password = text;
                    root.failure = "";
                }

                Keys.onPressed: event => {
                    if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                        root.submit();
                        event.accepted = true;
                    } else if (event.key === Qt.Key_Escape) {
                        root.password = "";
                        sessionMenu.visible = false;
                        event.accepted = true;
                    }
                }
            }

            Row {
                anchors {
                    left: parent.left
                    leftMargin: 18
                    verticalCenter: parent.verticalCenter
                }
                spacing: 7
                visible: !root.busy

                Repeater {
                    model: Math.min(root.password.length, 18)

                    Rectangle {
                        width: 9
                        height: 9
                        radius: 4.5
                        color: root.textColor
                    }
                }
            }
            Text {
                anchors {
                    left: parent.left
                    leftMargin: 18
                    verticalCenter: parent.verticalCenter
                }
                visible: root.password === "" && !root.busy
                text: "Şifre"
                color: root.faintColor
                font.family: root.fontFamily
                font.pixelSize: 14
            }
            // Giriş yapılırken üç nokta yanıp söner
            Row {
                anchors.centerIn: parent
                spacing: 8
                visible: root.busy

                Repeater {
                    model: 3

                    Rectangle {
                        id: dot
                        required property int index
                        width: 8
                        height: 8
                        radius: 4
                        color: root.textColor
                        opacity: 0.3

                        SequentialAnimation on opacity {
                            running: root.busy
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

            // Ok: giriş yap
            Rectangle {
                anchors {
                    right: parent.right
                    rightMargin: 5
                    verticalCenter: parent.verticalCenter
                }
                visible: root.password !== "" && !root.busy
                width: 30
                height: 30
                radius: 15
                color: submitMouse.containsMouse ? root.buttonHover : root.buttonColor

                Icon {
                    anchors.centerIn: parent
                    name: "chevron-right"
                    size: 16
                    strokeWidth: 2.6
                    color: root.textColor
                }
                MouseArea {
                    id: submitMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.submit()
                }
            }
            MouseArea {
                anchors.fill: parent
                z: -1
                onClicked: input.forceActiveFocus()
            }
        }

        // Uyarı satırı: yanlış şifre > Caps Lock
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            height: 18
            text: root.failure !== "" ? root.failure : keyboard.capsLock ? "Caps Lock açık" : ""
            color: root.textColor
            font.family: root.fontFamily
            font.pixelSize: 13
            font.weight: Font.Medium
            layer.enabled: text !== ""
            layer.effect: TextShadow {}
        }
    }

    // ---------- Sol alt: oturum seçici ----------
    Item {
        id: sessionPicker

        anchors {
            left: parent.left
            bottom: parent.bottom
            margins: 30
        }
        visible: root.sessions.length > 1
        width: sessionButton.width
        height: sessionButton.height

        Rectangle {
            id: sessionButton

            width: sessionRow.implicitWidth + 28
            height: 36
            radius: 18
            color: sessionMouse.containsMouse || sessionMenu.visible ? root.buttonHover : root.buttonColor

            RowLayout {
                id: sessionRow
                anchors.centerIn: parent
                spacing: 8

                Icon {
                    name: "monitor"
                    size: 15
                    color: root.textColor
                }
                Text {
                    text: root.sessions[root.sessionIndex] ?? ""
                    color: root.textColor
                    font.family: root.fontFamily
                    font.pixelSize: 13
                    font.weight: Font.Medium
                }
                Icon {
                    name: "chevron-up"
                    size: 13
                    color: root.mutedColor
                    rotation: sessionMenu.visible ? 0 : 180
                }
            }
            MouseArea {
                id: sessionMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: sessionMenu.visible = !sessionMenu.visible
            }
        }

        // Yukarı açılan liste
        Rectangle {
            id: sessionMenu

            anchors {
                left: parent.left
                bottom: sessionButton.top
                bottomMargin: 8
            }
            visible: false
            width: Math.max(220, sessionList.implicitWidth + 12)
            height: sessionList.implicitHeight + 12
            radius: 14
            color: root.menuColor
            border.width: 1
            border.color: Qt.rgba(1, 1, 1, 0.11)

            Column {
                id: sessionList
                anchors.centerIn: parent
                width: parent.width - 12

                Repeater {
                    model: root.sessions

                    Rectangle {
                        id: sessionItem
                        required property int index
                        required property string modelData

                        width: sessionList.width
                        height: 34
                        radius: 9
                        color: itemMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : "transparent"

                        RowLayout {
                            anchors {
                                fill: parent
                                leftMargin: 10
                                rightMargin: 10
                            }
                            spacing: 8

                            Text {
                                Layout.fillWidth: true
                                text: sessionItem.modelData
                                color: root.textColor
                                font.family: root.fontFamily
                                font.pixelSize: 13
                                elide: Text.ElideRight
                            }
                            Icon {
                                visible: sessionItem.index === root.sessionIndex
                                name: "check"
                                size: 14
                                color: root.textColor
                            }
                        }
                        MouseArea {
                            id: itemMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.sessionIndex = sessionItem.index;
                                sessionMenu.visible = false;
                                input.forceActiveFocus();
                            }
                        }
                    }
                }
            }
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
            visible: sddm.canSuspend
            icon: "moon"
            label: "Uyku"
            onConfirmed: sddm.suspend()
        }
        PowerButton {
            visible: sddm.canReboot
            icon: "rotate-ccw"
            label: "Yeniden başlat"
            needsConfirm: true
            onConfirmed: sddm.reboot()
        }
        PowerButton {
            visible: sddm.canPowerOff
            icon: "power"
            label: "Kapat"
            needsConfirm: true
            onConfirmed: sddm.powerOff()
        }
    }

    Component.onCompleted: input.forceActiveFocus()

    // Duvar kâğıdının üstündeki yazılara hafif gölge
    component TextShadow: MultiEffect {
        shadowEnabled: true
        shadowColor: root.shadowColor
        shadowBlur: 0.7
        shadowVerticalOffset: 1
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
            color: powerButton.armed ? root.errorColor : powerMouse.containsMouse ? root.buttonHover : root.buttonColor

            Icon {
                anchors.centerIn: parent
                name: powerButton.icon
                size: 19
                color: root.textColor
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
            color: root.mutedColor
            font.family: root.fontFamily
            font.pixelSize: 12
        }
    }
}
