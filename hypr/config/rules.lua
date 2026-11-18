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

-- Noctalia panellerine buzlu cam. Katman adlarını `hyprctl layers` ile doğrula.
hl.layer_rule({
    name = "noctalia-blur",
    match = { namespace = "^noctalia-bar" },
    blur = true,
    ignore_alpha = 0.3,
})

-- desk: menüler ve kontrol merkezi hafifçe büyüyerek açılır, solarak kapanır.
-- Hızlar appearance.lua → layersIn / layersOut. Ses göstergesi (desk-osd) yalnızca solar.
hl.layer_rule({
    name = "desk-popin",
    match = { namespace = "^desk-(menu|control-center)$" },
    animation = "popin 92%",
})

-- Bar ve Noctalia'nın katmanları animasyonsuz: Noctalia kendi animasyonunu yapıyor,
-- bar da shell her yeniden yüklendiğinde titremesin.
hl.layer_rule({
    name = "no-anim-panels",
    match = { namespace = "^(noctalia.*|desk-bar)$" },
    no_anim = true,
})

-- Ekran görüntüsü seçim alanı animasyonsuz (Mango'daki kural)
hl.layer_rule({
    name = "selection-no-anim",
    match = { namespace = "^selection$" },
    no_anim = true,
})
