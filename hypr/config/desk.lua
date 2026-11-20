-- desk'in çalışırken Hyprland'e verdiği ayarlar. desk bunu şöyle çağırır:
--   hyprctl eval 'desk.set_power(true)'
-- hyprctl reload bu ayarı dosyadakine döndürür; desk "configreloaded" olayında yeniden verir.

desk = desk or {}

-- Pilde hafif görünüm (plan, Aşama 9): ekran 60 Hz, bulanıklık tek geçiş, animasyonlar %20 kısa.
-- Şarja takınca hepsi geri gelir.
function desk.set_power(on_battery)
    desk.set_refresh(on_battery and 60 or desk.laptop.refresh)
    hl.config({ decoration = { blur = { passes = on_battery and 1 or 2 } } })
    desk.apply_animations(on_battery and 0.8 or 1)
end

-- Ayarlar penceresindeki değerler (desk → Theming.qml). desk açılışta, ayar değişince ve
-- hyprctl reload'dan sonra çağırır:
--   hyprctl eval 'desk.apply_settings({ gaps_in = 5, gaps_out = 10, rounding = 8, … })'
-- Dosyalardaki değerler (appearance.lua, input.lua) desk açılana kadar geçerli; varsayılanlar aynı.
-- Klavye ayarları yalnızca değişince verilir: her seferinde verilseydi etkin düzen (TR/US) başa dönerdi.
-- Ayar dosyası her yüklendiğinde (hyprctl reload) klavye ayarları dosyadakine döner: bir sonraki
-- çağrıda hepsi yeniden verilsin
desk.applied = nil

local INPUT_KEYS = {
    "kb_layout", "kb_variant", "kb_options", "repeat_rate", "repeat_delay", "follow_mouse",
    "sensitivity", "natural_scroll", "tap_to_click", "disable_while_typing",
}

function desk.apply_settings(s)
    local previous = desk.applied or {}
    local config = {
        general = { gaps_in = s.gaps_in, gaps_out = s.gaps_out },
        decoration = {
            rounding = s.rounding,
            dim_inactive = s.dim_inactive,
            dim_strength = s.dim_strength,
            shadow = { enabled = s.shadow },
        },
        animations = { enabled = s.animations },
    }

    local input_changed = false
    for _, key in ipairs(INPUT_KEYS) do
        if previous[key] ~= s[key] then
            input_changed = true
        end
    end
    if input_changed then
        config.input = {
            kb_layout = s.kb_layout,
            kb_variant = s.kb_variant,
            kb_options = s.kb_options,
            repeat_rate = s.repeat_rate,
            repeat_delay = s.repeat_delay,
            follow_mouse = s.follow_mouse,
            sensitivity = s.sensitivity,
            touchpad = {
                natural_scroll = s.natural_scroll,
                tap_to_click = s.tap_to_click,
                disable_while_typing = s.disable_while_typing,
            },
        }
    end

    hl.config(config)
    desk.applied = s
end
