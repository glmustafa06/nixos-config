import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.theme
import qs.components
import qs.services

// Kontrol merkezi: barın altında, sağda açılan buzlu cam panel.
// Bardaki her simge kendi sayfasıyla açar (ses → ses sayfası, Wi-Fi → ağ listesi …);
// kontrol merkezi simgesi genel sayfayla. Sayfalar üst üste açılır, geri oku bir öncekine döner.
// Açılıp kapanmasını bar yönetir; menülerle aynı düzen (Bar.qml: openMenu).
// Açılış/kapanış animasyonunu Hyprland yapar (rules.lua → desk-control-center);
// sayfa geçişlerini burası: yeni sayfa sağdan, geri dönülen soldan kısa bir kaymayla gelir.
PanelWindow {
    id: root

    property var controller: null
    readonly property string menuKey: "control-center"
    readonly property bool open: controller !== null && controller.openMenu === menuKey

    // Açık sayfalar, en sondaki görünür: [{ name, data }]
    // Sayfalar: main, wifi, wifi-network, wifi-saved, wifi-hidden,
    //           bluetooth, bluetooth-device, sound, battery, session
    property var stack: [
        {
            name: "main",
            data: null
        }
    ]
    readonly property string page: stack[stack.length - 1].name
    readonly property var pageData: stack[stack.length - 1].data
    readonly property string rootPage: stack[0].name
    readonly property bool canGoBack: stack.length > 1

    // Odak yakalama için (bar ile birlikte)
    readonly property var windows: visible ? [root] : []

    // Sayfa geçişinin yönü: 1 ileri (sağdan), -1 geri (soldan), 0 yerinde (yalnızca belirir).
    // Panel kapalıyken açılan sayfada geçiş yok; o sırada Hyprland paneli açıyor.
    property int direction: 0
    property bool animateNext: false

    function changePage(newStack, newDirection) {
        direction = newDirection;
        animateNext = open;
        stack = newStack;
    }

    // Bar açarken: sayfa yığınını bu sayfayla başlat (bilinmeyen ad gelirse ana sayfa)
    function reset(name) {
        changePage([
            {
                name: pageComponents[name] ? name : "main",
                data: null
            }
        ], 0);
    }
    // Üstüne yeni sayfa aç (geri oku bir öncekine döner)
    function show(name, data) {
        changePage(stack.concat([
            {
                name: name,
                data: data ?? null
            }
        ]), 1);
    }
    function back() {
        if (stack.length > 1)
            changePage(stack.slice(0, -1), -1);
    }
    function close() {
        controller?.closeMenus();
    }

    // Esc: önceki sayfaya dön; ilk sayfadaysa kapat
    function handleKey(event) {
        if (event.key !== Qt.Key_Escape)
            return false;
        if (canGoBack)
            back();
        else
            close();
        return true;
    }

    onOpenChanged: {
        controller?.menuOpened(root, open);
        Ui.controlCenterOpen = open;
        animateNext = false;
    }

    visible: open
    color: "transparent"
    screen: controller?.screen ?? null

    anchors {
        top: true
        right: true
    }
    margins.top: Metrics.popoutTop
    margins.right: Metrics.popoutRight
    exclusionMode: ExclusionMode.Ignore
    // Wi-Fi şifresi yazılabilsin diye klavye alabilir (tıklanınca)
    focusable: true
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "desk-control-center"

    implicitWidth: Metrics.controlCenterWidth
    implicitHeight: panel.implicitHeight

    BackgroundEffect.blurRegion: Region {
        item: panel
        radius: panel.radius
    }

    Rectangle {
        id: panel

        width: parent.width
        height: parent.height
        implicitHeight: pages.implicitHeight + 24
        radius: 24
        color: Colors.panel
        border.width: 1
        border.color: Colors.panelBorder

        GlassEdge {}

        FocusScope {
            anchors.fill: parent
            focus: true
            Keys.onPressed: event => event.accepted = root.handleKey(event)

            Loader {
                id: pages

                anchors {
                    left: parent.left
                    right: parent.right
                    top: parent.top
                    margins: 12
                }
                focus: true
                // Kapalıyken sayfa yüklenmez (Wi-Fi taraması gibi işler durur)
                active: root.open
                sourceComponent: pageComponents[root.page] ?? mainPage

                transform: Translate {
                    id: pageShift
                }

                onLoaded: {
                    if (root.animateNext)
                        pageIn.restart();
                    root.animateNext = false;
                }
            }

            ParallelAnimation {
                id: pageIn

                NumberAnimation {
                    target: pages
                    property: "opacity"
                    from: 0
                    to: 1
                    duration: Metrics.durationPage
                    easing.type: Easing.OutCubic
                }
                NumberAnimation {
                    target: pageShift
                    property: "x"
                    from: 18 * root.direction
                    to: 0
                    duration: Metrics.durationPage
                    easing.type: Easing.OutCubic
                }
            }
        }
    }

    readonly property var pageComponents: ({
            "main": mainPage,
            "wifi": wifiPage,
            "wifi-network": wifiNetworkPage,
            "wifi-saved": wifiSavedPage,
            "wifi-hidden": wifiHiddenPage,
            "bluetooth": bluetoothPage,
            "bluetooth-device": bluetoothDevicePage,
            "sound": soundPage,
            "battery": batteryPage,
            "session": sessionPage
        })

    Component {
        id: mainPage
        MainPage {
            center: root
        }
    }
    Component {
        id: wifiPage
        WifiPage {
            center: root
        }
    }
    Component {
        id: wifiNetworkPage
        WifiNetworkPage {
            center: root
            network: root.pageData
        }
    }
    Component {
        id: wifiSavedPage
        WifiSavedPage {
            center: root
        }
    }
    Component {
        id: wifiHiddenPage
        WifiHiddenPage {
            center: root
        }
    }
    Component {
        id: bluetoothPage
        BluetoothPage {
            center: root
        }
    }
    Component {
        id: bluetoothDevicePage
        BluetoothDevicePage {
            center: root
            device: root.pageData
        }
    }
    Component {
        id: soundPage
        SoundPage {
            center: root
        }
    }
    Component {
        id: batteryPage
        BatteryPage {
            center: root
        }
    }
    Component {
        id: sessionPage
        SessionPage {
            center: root
        }
    }
}
