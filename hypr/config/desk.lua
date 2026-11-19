-- desk'in çalışırken Hyprland'e verdiği ayarlar. desk bunu şöyle çağırır:
--   hyprctl eval 'desk.set_power(true)'
-- hyprctl reload bu ayarı dosyadakine döndürür; desk "configreloaded" olayında yeniden verir.

desk = desk or {}

-- -- Pilde hafif görünüm (plan, Aşama 9): ekran 60 Hz, bulanıklık tek geçiş, animasyonlar %20 kısa.
-- -- Şarja takınca hepsi geri gelir.
-- function desk.set_power(on_battery)
--     desk.set_refresh(on_battery and 60 or desk.laptop.refresh)
--     hl.config({ decoration = { blur = { passes = on_battery and 1 or 2 } } })
--     desk.apply_animations(on_battery and 0.8 or 1)
-- end
