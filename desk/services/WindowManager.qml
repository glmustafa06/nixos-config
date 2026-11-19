pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland

// Hyprland ile konuşan tek yer: etkin alan ve pencere bilgisi, pencere ve düzen komutları.
// Bar, ada ve menüler bilgiyi buradan okur, komutları buradan gönderir.
Singleton {
    id: root

    // --- Etkin alan ve düzeni
    readonly property var workspace: Hyprland.focusedWorkspace
    readonly property string layout: workspace?.lastIpcObject?.tiledLayout ?? "dwindle"

    // --- Etkin pencere (başka bir alanda kaldıysa yok sayılır)
    readonly property var window: Hyprland.activeToplevel
    readonly property bool hasWindow: window !== null && window.workspace === workspace
    readonly property string appId: hasWindow ? appIdOf(window) : ""

    // Uygulamanın .desktop kaydı. Uygulama listesi açılışta arka planda taranıyor;
    // liste dolunca bu değer yeniden hesaplansın diye listeye bağımlı yapılıyor.
    readonly property var desktopEntry: {
        if (appId === "")
            return null;
        DesktopEntries.applications.values;
        return DesktopEntries.heuristicLookup(appId);
    }
    readonly property string appName: {
        if (appId === "")
            return "Masaüstü";
        return desktopEntry ? desktopEntry.name : appId.charAt(0).toUpperCase() + appId.slice(1);
    }

    function appIdOf(toplevel) {
        return toplevel?.wayland?.appId ?? toplevel?.lastIpcObject?.class ?? "";
    }

    // Bir uygulamanın bütün pencereleri (bütün alanlarda)
    function windowsOf(id) {
        return Hyprland.toplevels.values.filter(t => appIdOf(t) === id);
    }

    // --- Pencerenin durumu: Hyprland'in son JSON çıktısından
    // (fullscreen bir bit alanı: 1 = büyütülmüş, 2 = tam ekran)
    function isFloating(toplevel) {
        return toplevel?.lastIpcObject?.floating === true;
    }
    function isPinned(toplevel) {
        return toplevel?.lastIpcObject?.pinned === true;
    }
    function isMaximized(toplevel) {
        return ((toplevel?.lastIpcObject?.fullscreen ?? 0) & 1) !== 0;
    }
    function isFullscreen(toplevel) {
        return ((toplevel?.lastIpcObject?.fullscreen ?? 0) & 2) !== 0;
    }

    // --- Komutlar
    // Hyprland 0.57'de "dispatch" bir Lua ifadesi alır: hl.dispatch(<ifade>) olarak çalışır.
    // İfade bir dispatcher (hl.dsp.…) ya da bir Lua fonksiyonu olabilir.
    function dispatch(code) {
        Hyprland.dispatch(code);
    }

    // Pencereyi adresiyle seçer; komut, menü açıkken odak kaysa bile doğru pencereye gider
    function selector(toplevel) {
        return `"address:0x${toplevel.address}"`;
    }

    function toggleFloating(toplevel) {
        dispatch(`hl.dsp.window.float({ action = "toggle", window = ${selector(toplevel)} })`);
    }
    function toggleFullscreen(toplevel) {
        dispatch(`hl.dsp.window.fullscreen({ mode = "fullscreen", window = ${selector(toplevel)} })`);
    }
    function toggleMaximized(toplevel) {
        dispatch(`hl.dsp.window.fullscreen({ mode = "maximized", window = ${selector(toplevel)} })`);
    }
    function close(toplevel) {
        dispatch(`hl.dsp.window.close({ window = ${selector(toplevel)} })`);
    }
    // Pencereye git (başka alandaysa o alana geçilir)
    function focus(toplevel) {
        dispatch(`hl.dsp.focus({ window = ${selector(toplevel)} })`);
    }
    // workspace: alan numarası ya da "empty" (ilk boş alan)
    function moveToWorkspace(toplevel, workspace) {
        const target = typeof workspace === "number" ? workspace : `"${workspace}"`;
        dispatch(`hl.dsp.window.move({ workspace = ${target}, window = ${selector(toplevel)} })`);
    }
    // Hyprland yalnızca yüzen pencereyi sabitleyebiliyor: önce yüzdür, sonra sabitle
    function togglePinned(toplevel) {
        const w = selector(toplevel);
        dispatch(`function() `
            + `hl.dispatch(hl.dsp.window.float({ action = "enable", window = ${w} })) `
            + `hl.dispatch(hl.dsp.window.pin({ action = "toggle", window = ${w} })) `
            + `end`);
    }

    // Düzen komutları odaktaki pencereye gider (menü açıkken odak değişmiyor)
    function layoutMessage(message) {
        dispatch(`hl.dsp.layout("${message}")`);
    }
    // layouts.lua'daki desk.set_layout: alan kuralını yazar, Super+N ile aynı yol
    function setLayout(name) {
        dispatch(`function() desk.set_layout("${name}") end`);
    }
    function cycleLayout() {
        dispatch(`function() desk.cycle_layout() end`);
    }

    // Hyprland bu bilgileri kendiliğinden göndermiyor; ilgili olaylarda yeniden sorulur.
    // "custom": layouts.lua düzen değişince desk-layout olayı yolluyor.
    // Olaylar çoğu zaman peş peşe gelir (pencere açılınca openwindow + activewindowv2 …);
    // kısa bir beklemeyle toplanıp Hyprland'e bir kez sorulur.
    property bool workspacesDirty: false
    property bool toplevelsDirty: false

    Connections {
        target: Hyprland

        function onRawEvent(event) {
            const name = event.name;
            if (["workspacev2", "createworkspacev2", "focusedmon", "custom"].includes(name)) {
                root.workspacesDirty = true;
                root.toplevelsDirty = true; // pencerelerin yeri değişmiş olabilir (dock gizlenmesi için)
            }
            else if (["activewindowv2", "openwindow", "closewindow", "changefloatingmode", "fullscreen", "pin", "movewindowv2"].includes(name))
                root.toplevelsDirty = true;
            else
                return;
            refreshTimer.start();
        }
    }

    Timer {
        id: refreshTimer
        interval: 30
        onTriggered: {
            if (root.workspacesDirty)
                Hyprland.refreshWorkspaces();
            if (root.toplevelsDirty)
                Hyprland.refreshToplevels();
            root.workspacesDirty = false;
            root.toplevelsDirty = false;
        }
    }
}
