-- Kısayollar: Mango'dakilerin karşılığı.
-- Aynı tuşu iki kez bağlama; 0.57 reddeder (plan: Sorun 3).
-- Super+N, Super+R, Super+C ve Super+Alt+D/S/M layouts.lua'da.

local SUPER = "SUPER"
local LID_SCRIPT = "~/.config/hypr/scripts/lid.sh" -- exec_cmd kabukta çalıştığı için ~ açılır
-- desk'e IPC ile ulaşmak için (shell.qml'deki IpcHandler'lar). -c desk: ~/.config/quickshell/desk,
-- desk'in klasörüne bağlı (desk/nix/home.nix → desk.source); klasör taşınsa da burası değişmez.
local DESK = "qs ipc -c desk call "
local SCREENSHOT = "~/.config/quickshell/desk/scripts/screenshot.sh"

-- Uygulamalar
hl.bind(SUPER .. " + RETURN", hl.dsp.exec_cmd("kitty"))
hl.bind(SUPER .. " + E", hl.dsp.exec_cmd("dolphin"))
hl.bind(SUPER .. " + B", hl.dsp.exec_cmd("zen"))

-- desk: arama, kontrol merkezi, pano, duvar kâğıdı, oturum
hl.bind(SUPER .. " + SPACE", hl.dsp.exec_cmd(DESK .. "search toggle"))
hl.bind(SUPER .. " + S", hl.dsp.exec_cmd(DESK .. "controlcenter toggle"))
hl.bind(SUPER .. " + V", hl.dsp.exec_cmd(DESK .. "search clipboard"))
hl.bind(SUPER .. " + W", hl.dsp.exec_cmd(DESK .. "wallpaper toggle"))
hl.bind(SUPER .. " + SHIFT + ESCAPE", hl.dsp.exec_cmd(DESK .. "controlcenter open session"))
-- Kilit: hypridle desk'in kilit ekranını açar (hypridle.conf → lock_cmd)
hl.bind(SUPER .. " + ESCAPE", hl.dsp.exec_cmd("loginctl lock-session"), { locked = true })

-- Ekran görüntüsü: panoya ve Resimler/Ekran görüntüleri'ne (Print: alan seç, Shift+Print: bütün ekran)
hl.bind("Print", hl.dsp.exec_cmd(SCREENSHOT .. " region"))
hl.bind("SHIFT + Print", hl.dsp.exec_cmd(SCREENSHOT .. " full"))

-- Ses, parlaklık, medya tuşları.
-- Önce değer değişir, sonra desk'in göstergesi açılır. desk kapalı olsa da tuşlar çalışır.
-- (Ses değişikliğini desk kendisi de görüyor; IPC en üst/alt sınırda da gösterge çıksın diye.)
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+; " .. DESK .. "osd volume"), { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-; " .. DESK .. "osd volume"), { locked = true, repeating = true })
hl.bind("XF86AudioMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle; " .. DESK .. "osd volume"), { locked = true })
hl.bind("XF86AudioMicMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"), { locked = true })
hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd("brightnessctl -d amdgpu_bl1 -e4 -n2 set 5%+; " .. DESK .. "osd brightness"), { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl -d amdgpu_bl1 -e4 -n2 set 5%-; " .. DESK .. "osd brightness"), { locked = true, repeating = true })
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
    { "left", "H", "left", -50, 0 },
    { "right", "L", "right", 50, 0 },
    { "up", "K", "up", 0, -50 },
    { "down", "J", "down", 0, 50 },
}

for _, d in ipairs(DIRECTIONS) do
    local arrow, letter, dir, dx, dy = d[1], d[2], d[3], d[4], d[5]
    for _, key in ipairs({ arrow, letter }) do
        hl.bind(SUPER .. " + " .. key, hl.dsp.focus({ direction = dir }))
        hl.bind(SUPER .. " + SHIFT + " .. key, hl.dsp.window.swap({ direction = dir }))
        hl.bind(SUPER .. " + CTRL + " .. key, hl.dsp.window.resize({ x = dx, y = dy, relative = true }), { repeating = true })
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
