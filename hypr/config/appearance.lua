-- Görünüm: resimlerdeki ölçüler (köşe 12, pencereler arası 10, kenar 10)

hl.config({
    general = {
        gaps_in = 5, -- iki pencere arası 2 × 5 = 10 px
        gaps_out = 10,
        border_size = 2,
        col = {
            -- Geçici sabit vurgu rengi; Aşama 1'de matugen duvar kâğıdından üretecek
            active_border = "rgba(5dbfaeff)",
            inactive_border = "rgba(ffffff14)",
        },
        resize_on_border = true,
        layout = "dwindle",
    },

    decoration = {
        rounding = 12,
        rounding_power = 2,
        active_opacity = 1.0,
        inactive_opacity = 1.0,

        shadow = {
            enabled = true,
            range = 24,
            render_power = 3,
            color = 0x66000000,
        },

        -- Buzlu cam. Pil için makul değerler (plan: Sorun 29)
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

-- Animasyonlar: Mango'daki hızlar (1 birim = 100 ms)
hl.curve("smooth", { type = "bezier", points = { {0.23, 1}, {0.32, 1} } })
hl.curve("linear", { type = "bezier", points = { {0, 0}, {1, 1} } })

hl.animation({ leaf = "global",     enabled = true, speed = 4,   bezier = "default" })
hl.animation({ leaf = "windows",    enabled = true, speed = 2,   bezier = "smooth" })                         -- taşıma 200 ms
hl.animation({ leaf = "windowsIn",  enabled = true, speed = 1.8, bezier = "smooth", style = "popin 90%" })    -- açılma 180 ms
hl.animation({ leaf = "windowsOut", enabled = true, speed = 1.5, bezier = "linear", style = "popin 90%" })    -- kapanma 150 ms
hl.animation({ leaf = "border",     enabled = true, speed = 2,   bezier = "smooth" })
hl.animation({ leaf = "fade",       enabled = true, speed = 1.5, bezier = "smooth" })
hl.animation({ leaf = "workspaces", enabled = true, speed = 1.8, bezier = "smooth", style = "slide" })        -- alan değişimi 180 ms
-- Katmanlar (menüler, paneller): kısa bir solma; desk'in menüleri ve kontrol merkezi ayrıca
-- hafifçe büyüyerek açılır (rules.lua → desk-popin). Noctalia kendi animasyonunu yaptığı için
-- ona ve bara animasyon yok (rules.lua → no-anim-panels).
hl.animation({ leaf = "layers",        enabled = true, speed = 1.3, bezier = "smooth", style = "fade" })
hl.animation({ leaf = "layersIn",      enabled = true, speed = 1.3, bezier = "smooth", style = "fade" })  -- açılma 130 ms
hl.animation({ leaf = "layersOut",     enabled = true, speed = 1,   bezier = "linear", style = "fade" })  -- kapanma 100 ms
hl.animation({ leaf = "fadeLayersIn",  enabled = true, speed = 1.3, bezier = "smooth" })
hl.animation({ leaf = "fadeLayersOut", enabled = true, speed = 1,   bezier = "linear" })
