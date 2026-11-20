-- Pencere ve katman kuralları

-- Ayar pencereleri ortada, yüzer açılsın (Mango'daki liste)
local FLOATING = {
    "nm-connection-editor",
    "blueman-manager",
    "com.saivert.pwvucontrol",
    "org.pulseaudio.pavucontrol",
}

for _, class in ipairs(FLOATING) do
    hl.window_rule({
        name = "float-" .. class,
        match = { class = "^" .. class .. "$" },
        float = true,
        size = { "monitor_w * 0.55", "monitor_h * 0.65" },
        center = true,
    })
end

-- desk'in Ayarlar penceresi: ortada yüzer, boyutunu kendisi seçer (shell.qml → AppId desk-settings)
hl.window_rule({
    name = "float-desk-settings",
    match = { class = "^desk-settings$" },
    float = true,
    center = true,
})

-- Ekran görüntüsü düzenleyicisi (Satty): ortada yüzer; boyutunu resme göre kendisi seçer
hl.window_rule({
    name = "float-satty",
    match = { class = "^com\\.gabm\\.satty$" },
    float = true,
    center = true,
})

-- Dosya seçme penceresi
hl.window_rule({
    name = "float-portal",
    match = { class = "^xdg-desktop-portal-gtk$" },
    float = true,
    size = { "monitor_w * 0.6", "monitor_h * 0.7" },
    center = true,
})

-- Uygulamaların kendini "büyütme" isteklerini yok say
hl.window_rule({
    name = "suppress-maximize",
    match = { class = ".*" },
    suppress_event = "maximize",
})

-- XWayland sürükleme sorunu (Hyprland'in önerdiği kural)
hl.window_rule({
    name = "fix-xwayland-drags",
    match = { class = "^$", title = "^$", xwayland = true, float = true, fullscreen = false, pin = false },
    no_focus = true,
})

-- desk: menüler, kontrol merkezi, bildirim merkezi, arama ve duvar kâğıdı seçici hafifçe
-- büyüyerek açılır, solarak kapanır. Hızlar appearance.lua → layersIn / layersOut.
-- Ses göstergesi (desk-osd) yalnızca solar.
hl.layer_rule({
    name = "desk-popin",
    match = { namespace = "^desk-(menu|control-center|notification-center|search|wallpaper-picker)$" },
    animation = "popin 92%",
})

-- Bar, dock ve duvar kâğıdı animasyonsuz: dock kendisi kayarak gizlenip çıkıyor, duvar kâğıdı
-- kendi geçişini yapıyor, bar da shell her yeniden yüklendiğinde titremesin.
-- Ekran görüntüsünün seçim ekranı bir anda gelsin (donmuş ekran), önizleme kendisi kayarak gelir;
-- pencere değiştirici de bir anda (Alt+Tab hızlı olmalı).
hl.layer_rule({
    name = "no-anim-panels",
    match = { namespace = "^(desk-bar|desk-dock.*|desk-wallpaper|desk-screenshot|desk-shot-preview|desk-switcher)$" },
    no_anim = true,
})

-- Ekran görüntüsü seçim alanı animasyonsuz (Mango'daki kural)
hl.layer_rule({
    name = "selection-no-anim",
    match = { namespace = "^selection$" },
    no_anim = true,
})
