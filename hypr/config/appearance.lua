-- Görünüm: köşe 8, pencereler arası 10, ekran kenarına 10; kenarlık yok

hl.config({
    general = {
        gaps_in = 5, -- iki pencere arası 2 × 5 = 10 px
        gaps_out = 10,
        -- Kenarlık yok; odaktaki pencere, ötekiler hafifçe karardığı için belli olur (dim_inactive)
        border_size = 0,
        resize_on_border = true, -- kenarlık olmasa da kenardan tutup boyutlandırılır
        layout = "dwindle",
    },

    decoration = {
        rounding = 8,
        rounding_power = 2,
        active_opacity = 1.0,
        inactive_opacity = 1.0,
        -- Odakta olmayan pencereler hafifçe kararır (kenarlığın yerine)
        dim_inactive = true,
        dim_strength = 0.15,

        shadow = {
            enabled = true,
            range = 24,
            render_power = 3,
            color = 0x66000000,
        },

        -- Buzlu cam. Pil için makul değerler (plan: Sorun 29); pilde geçiş 1 (config/desk.lua)
        blur = {
            enabled = true,
            size = 5,
            passes = 2,
            new_optimizations = true,
            vibrancy = 0.17,
            -- Camın arkasını biraz karartır: arkada beyaz bir sayfa olsa da yazılar okunur.
            -- desk/theme/Colors.qml'deki cam saydamlığıyla birlikte hesaplandı;
            -- değiştirirsen desk'te `python3 scripts/contrast.py` çalıştır.
            brightness = 0.8,
            popups = true,
        },
    },

    animations = {
        enabled = true,
    },

    misc = {
        disable_hyprland_logo = true,
        disable_splash_rendering = true,
        force_default_wallpaper = 0,
        focus_on_activate = false,
    },
})

-- Animasyonlar: Mango'daki hızlar (hız 1 = 100 ms)
-- Hepsi aynı yumuşak eğriyle girer, kapanışlar düz çizgiyle çıkar. Ayrıca ayarlanmayanlar
-- (özel alan, ekran takılınca …) "global"i kullanır, o da aynı eğride.
hl.curve("smooth", { type = "bezier", points = { { 0.23, 1 }, { 0.32, 1 } } })
hl.curve("linear", { type = "bezier", points = { { 0, 0 }, { 1, 1 } } })

-- Katmanlar (menüler, paneller): kısa bir solma; desk'in menüleri, kontrol merkezi, arama ve
-- seçiciler ayrıca hafifçe büyüyerek açılır (rules.lua → desk-popin). Bar, dock ve duvar kâğıdı
-- animasyonsuz (rules.lua → no-anim-panels).
local ANIMATIONS = {
    { leaf = "global",        speed = 2,   bezier = "smooth" },
    { leaf = "windows",       speed = 2,   bezier = "smooth" },                      -- taşıma 200 ms
    { leaf = "windowsIn",     speed = 1.8, bezier = "smooth", style = "popin 90%" }, -- açılma 180 ms
    { leaf = "windowsOut",    speed = 1.5, bezier = "linear", style = "popin 90%" }, -- kapanma 150 ms
    { leaf = "border",        speed = 2,   bezier = "smooth" },
    { leaf = "fade",          speed = 1.5, bezier = "smooth" },
    { leaf = "workspaces",    speed = 1.8, bezier = "smooth", style = "slide" }, -- alan değişimi 180 ms
    { leaf = "layers",        speed = 1.3, bezier = "smooth", style = "fade" },
    { leaf = "layersIn",      speed = 1.3, bezier = "smooth", style = "fade" },  -- açılma 130 ms
    { leaf = "layersOut",     speed = 1,   bezier = "linear", style = "fade" },  -- kapanma 100 ms
    { leaf = "fadeLayersIn",  speed = 1.3, bezier = "smooth" },
    { leaf = "fadeLayersOut", speed = 1,   bezier = "linear" },
}

-- scale < 1: animasyonlar kısalır (pilde 0.8; config/desk.lua)
desk = desk or {}
function desk.apply_animations(scale)
    for _, a in ipairs(ANIMATIONS) do
        hl.animation({ leaf = a.leaf, enabled = true, speed = a.speed * scale, bezier = a.bezier, style = a.style })
    end
end

desk.apply_animations(1)
