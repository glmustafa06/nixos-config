-- Kısayollar: Mango'dakilerin karşılığı.
-- Aynı tuşu iki kez bağlama; 0.57 reddeder (plan: Sorun 3).
-- description: desk'in Ayarlar → Kısayollar sayfasında görünür ("Grup: ne yapar"; hyprctl binds -j).
-- Açıklaması olmayanlar (medya tuşları, kapak) orada listelenmez.
-- Super+N, Super+R, Super+C ve Super+Alt+D/S/M layouts.lua'da.

local SUPER = "SUPER"
local LID_SCRIPT = "~/.config/hypr/scripts/lid.sh" -- exec_cmd kabukta çalıştığı için ~ açılır
-- desk'e IPC ile ulaşmak için (shell.qml'deki IpcHandler'lar). -c desk: ~/.config/quickshell/desk,
-- desk'in klasörüne bağlı (desk/nix/home.nix → desk.source); klasör taşınsa da burası değişmez.
local DESK = "qs ipc -c desk call "
local SCREENSHOT = "~/.config/quickshell/desk/scripts/screenshot.sh"

-- Uygulamalar
hl.bind(SUPER .. " + RETURN", hl.dsp.exec_cmd("kitty"), { description = "Uygulamalar: Terminal (kitty)" })
hl.bind(SUPER .. " + E", hl.dsp.exec_cmd("dolphin"), { description = "Uygulamalar: Dosyalar (Dolphin)" })
hl.bind(SUPER .. " + B", hl.dsp.exec_cmd("zen"), { description = "Uygulamalar: Tarayıcı (Zen)" })

-- desk: arama, kontrol merkezi, pano, duvar kâğıdı, ayarlar, oturum
hl.bind(SUPER .. " + SPACE", hl.dsp.exec_cmd(DESK .. "search toggle"), { description = "desk: Arama" })
hl.bind(SUPER .. " + S", hl.dsp.exec_cmd(DESK .. "controlcenter toggle"), { description = "desk: Kontrol merkezi" })
hl.bind(SUPER .. " + V", hl.dsp.exec_cmd(DESK .. "search clipboard"), { description = "desk: Pano geçmişi" })
hl.bind(SUPER .. " + W", hl.dsp.exec_cmd(DESK .. "wallpaper toggle"), { description = "desk: Duvar kâğıdı" })
hl.bind(SUPER .. " + COMMA", hl.dsp.exec_cmd(DESK .. "settings toggle"), { description = "desk: Ayarlar" })
hl.bind(SUPER .. " + SHIFT + ESCAPE", hl.dsp.exec_cmd(DESK .. "controlcenter open session"), { description = "desk: Oturum (kapat, yeniden başlat)" })
-- Kilit: hypridle desk'in kilit ekranını açar (hypridle.conf → lock_cmd)
hl.bind(SUPER .. " + ESCAPE", hl.dsp.exec_cmd("loginctl lock-session"), { locked = true, description = "desk: Kilitle" })

-- Ekran görüntüsü ve kaydı (desk): Print seçim ekranını açar (alan, pencere, ekran, kayıt);
-- kayıt sürerken Print durdurur. Shift+Print bütün ekranı hemen çeker.
-- desk çalışmıyorsa eski betik (slurp ile alan seçer).
hl.bind("Print", hl.dsp.exec_cmd(DESK .. "screenshot start || " .. SCREENSHOT .. " region"), { description = "Ekran görüntüsü: Seç (alan, pencere, ekran, kayıt)" })
hl.bind("SHIFT + Print", hl.dsp.exec_cmd(DESK .. "screenshot screen || " .. SCREENSHOT .. " full"), { description = "Ekran görüntüsü: Bütün ekran" })

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
hl.bind("ALT + F4", hl.dsp.window.close(), { description = "Pencereler: Kapat" })
hl.bind(SUPER .. " + F", hl.dsp.window.fullscreen({ mode = "fullscreen" }), { description = "Pencereler: Tam ekran" })
hl.bind(SUPER .. " + M", hl.dsp.window.fullscreen({ mode = "maximized" }), { description = "Pencereler: Büyüt" })
hl.bind(SUPER .. " + SHIFT + F", hl.dsp.window.float({ action = "toggle" }), { description = "Pencereler: Yüzer / döşeli" })

-- Pencere değiştirici (desk, macOS'taki gibi): Alt basılıyken Tab pencereler arasında gezer, Alt bırakılınca
-- seçilene geçilir; Shift+Tab geri, Esc vazgeç. Alt+Tab desk'e "next" der ve "switcher" tuş takımına girer;
-- Alt bırakılınca (ya da Esc) tuş takımından çıkılır. desk çalışmıyorsa Alt+Tab sıradaki pencereye geçer.
local SWITCHER = DESK .. "switcher "

local function switcher_open(action)
    return function()
        hl.dispatch(hl.dsp.exec_cmd(SWITCHER .. action .. " || hyprctl dispatch 'hl.dsp.window.cycle_next()'"))
        hl.dispatch(hl.dsp.submap("switcher"))
    end
end

local function switcher_end(action)
    return function()
        hl.dispatch(hl.dsp.exec_cmd(SWITCHER .. action))
        hl.dispatch(hl.dsp.submap("reset"))
    end
end

hl.bind("ALT + TAB", switcher_open("next"), { description = "Pencereler: Pencere değiştirici" })
hl.bind("ALT + SHIFT + TAB", switcher_open("previous"), { description = "Pencereler: Pencere değiştirici (geri)" })

hl.define_submap("switcher", function()
    hl.bind("ALT + TAB", hl.dsp.exec_cmd(SWITCHER .. "next"))
    hl.bind("ALT + SHIFT + TAB", hl.dsp.exec_cmd(SWITCHER .. "previous"))
    hl.bind("ALT + Alt_L", switcher_end("commit"), { release = true, transparent = true })
    hl.bind("ALT + Alt_R", switcher_end("commit"), { release = true, transparent = true })
    hl.bind("ALT + ESCAPE", switcher_end("cancel"))
    hl.bind("ESCAPE", switcher_end("cancel"))
end)

-- Odak (oklar ve hjkl), yer değiştirme (Shift), boyut (Ctrl)
local DIRECTIONS = {
    { "left", "H", "left", -50, 0, "sola" },
    { "right", "L", "right", 50, 0, "sağa" },
    { "up", "K", "up", 0, -50, "yukarı" },
    { "down", "J", "down", 0, 50, "aşağı" },
}

for _, d in ipairs(DIRECTIONS) do
    local arrow, letter, dir, dx, dy, word = d[1], d[2], d[3], d[4], d[5], d[6]
    for _, key in ipairs({ arrow, letter }) do
        hl.bind(SUPER .. " + " .. key, hl.dsp.focus({ direction = dir }), { description = "Odak: Odağı " .. word .. " taşı" })
        hl.bind(SUPER .. " + SHIFT + " .. key, hl.dsp.window.swap({ direction = dir }), { description = "Odak: Pencereyi " .. word .. " taşı" })
        hl.bind(SUPER .. " + CTRL + " .. key, hl.dsp.window.resize({ x = dx, y = dy, relative = true }), { repeating = true, description = "Odak: Boyutu " .. word .. " değiştir" })
    end
end

-- Çalışma alanları 1–9: git (Super) ve pencereyi taşı (Super+Shift)
for i = 1, 9 do
    hl.bind(SUPER .. " + " .. i, hl.dsp.focus({ workspace = i }), { description = "Çalışma alanları: Alana git" })
    hl.bind(SUPER .. " + SHIFT + " .. i, hl.dsp.window.move({ workspace = i }), { description = "Çalışma alanları: Pencereyi alana taşı" })
end

-- Fare: Super + sol tık taşı, Super + sağ tık boyutlandır
hl.bind(SUPER .. " + mouse:272", hl.dsp.window.drag(), { mouse = true, description = "Pencereler: Sürükleyerek taşı" })
hl.bind(SUPER .. " + mouse:273", hl.dsp.window.resize(), { mouse = true, description = "Pencereler: Sürükleyerek boyutlandır" })

-- Ayarı yeniden yükle
hl.bind(SUPER .. " + SHIFT + R", hl.dsp.reload_config(), { description = "Sistem: Hyprland ayarını yeniden yükle" })

-- Kapak (anahtar adını `hyprctl devices` ile doğrula)
hl.bind("switch:on:Lid Switch", hl.dsp.exec_cmd(LID_SCRIPT .. " close"), { locked = true })
hl.bind("switch:off:Lid Switch", hl.dsp.exec_cmd(LID_SCRIPT .. " open"), { locked = true })
