-- Kısayollar: Mango'dakilerin karşılığı.
-- Aynı tuşu iki kez bağlama; 0.57 reddeder (plan: Sorun 3).
-- Super+N, Super+R ve Super+Alt+D/S/M layouts.lua'da.

local SUPER = "SUPER"
local LID_SCRIPT = "~/.config/hypr/scripts/lid.sh" -- exec_cmd kabukta çalıştığı için ~ açılır
local NOCTALIA = "noctalia msg "

-- Uygulamalar
hl.bind(SUPER .. " + RETURN", hl.dsp.exec_cmd("kitty"))
hl.bind(SUPER .. " + E", hl.dsp.exec_cmd("dolphin"))
hl.bind(SUPER .. " + B", hl.dsp.exec_cmd("zen"))

-- Noctalia (geçici shell)
hl.bind(SUPER .. " + SPACE", hl.dsp.exec_cmd(NOCTALIA .. "panel-toggle launcher"))
hl.bind(SUPER .. " + S", hl.dsp.exec_cmd(NOCTALIA .. "panel-toggle control-center"))
hl.bind(SUPER .. " + SHIFT + S", hl.dsp.exec_cmd(NOCTALIA .. "settings-toggle"))
hl.bind(SUPER .. " + W", hl.dsp.exec_cmd(NOCTALIA .. "panel-toggle wallpaper"))
hl.bind(SUPER .. " + V", hl.dsp.exec_cmd(NOCTALIA .. "panel-toggle clipboard"))
hl.bind(SUPER .. " + SHIFT + ESCAPE", hl.dsp.exec_cmd(NOCTALIA .. "panel-toggle session"))
hl.bind(SUPER .. " + ESCAPE", hl.dsp.exec_cmd("loginctl lock-session"), { locked = true })

-- Ekran görüntüsü
hl.bind("Print", hl.dsp.exec_cmd(NOCTALIA .. "screenshot-region"))
hl.bind("SHIFT + Print",
    hl.dsp.exec_cmd("grim - | wl-copy && notify-send 'Ekran görüntüsü' 'Tüm ekran panoya kopyalandı'"))

-- Ses, parlaklık, medya tuşları (Noctalia değişikliği görüp göstergesini açar)
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"),
    { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"),
    { locked = true, repeating = true })
hl.bind("XF86AudioMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"), { locked = true })
hl.bind("XF86AudioMicMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"), { locked = true })
hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd("brightnessctl -d amdgpu_bl1 -e4 -n2 set 5%+"),
    { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl -d amdgpu_bl1 -e4 -n2 set 5%-"),
    { locked = true, repeating = true })
hl.bind("XF86AudioPlay", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioNext", hl.dsp.exec_cmd("playerctl next"), { locked = true })
hl.bind("XF86AudioPrev", hl.dsp.exec_cmd("playerctl previous"), { locked = true })

-- Pencereler
hl.bind("ALT + F4", hl.dsp.window.close())
hl.bind(SUPER .. " + F", hl.dsp.window.fullscreen({ mode = "fullscreen" }))
hl.bind(SUPER .. " + M", hl.dsp.window.fullscreen({ mode = "maximized" }))
hl.bind(SUPER .. " + SHIFT + F", hl.dsp.window.float({ action = "toggle" }))
hl.bind("ALT + TAB", hl.dsp.window.cycle_next())

-- Odak (oklar ve hjkl), yer değiştirme (Shift), boyut (Ctrl)
local DIRECTIONS = {
    { "left",  "H", "left",  -50, 0 },
    { "right", "L", "right", 50,  0 },
    { "up",    "K", "up",    0,   -50 },
    { "down",  "J", "down",  0,   50 },
}

for _, d in ipairs(DIRECTIONS) do
    local arrow, letter, dir, dx, dy = d[1], d[2], d[3], d[4], d[5]
    for _, key in ipairs({ arrow, letter }) do
        hl.bind(SUPER .. " + " .. key, hl.dsp.focus({ direction = dir }))
        hl.bind(SUPER .. " + SHIFT + " .. key, hl.dsp.window.swap({ direction = dir }))
        hl.bind(SUPER .. " + CTRL + " .. key, hl.dsp.window.resize({ x = dx, y = dy, relative = true }),
            { repeating = true })
    end
end

-- Çalışma alanları 1–9: git (Super) ve pencereyi taşı (Super+Shift)
for i = 1, 9 do
    hl.bind(SUPER .. " + " .. i, hl.dsp.focus({ workspace = i }))
    hl.bind(SUPER .. " + SHIFT + " .. i, hl.dsp.window.move({ workspace = i }))
end

-- Fare: Super + sol tık taşı, Super + sağ tık boyutlandır
hl.bind(SUPER .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
hl.bind(SUPER .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

-- Ayarı yeniden yükle
hl.bind(SUPER .. " + SHIFT + R", hl.dsp.reload_config())

-- Kapak (anahtar adını `hyprctl devices` ile doğrula)
hl.bind("switch:on:Lid Switch", hl.dsp.exec_cmd(LID_SCRIPT .. " close"), { locked = true })
hl.bind("switch:off:Lid Switch", hl.dsp.exec_cmd(LID_SCRIPT .. " open"), { locked = true })
