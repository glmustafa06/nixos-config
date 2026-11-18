-- Pencere düzenleri: varsayılan dwindle, alan başına scrolling / monocle

hl.config({
    dwindle = {
        preserve_split = true,
    },

    scrolling = {
        fullscreen_on_one_column = false,         -- tek pencere de 0.8 genişlikte, ortada
        column_width = 0.8,                       -- Mango: scroller_default_proportion
        explicit_column_widths = "0.5, 0.8, 1.0", -- Mango: scroller_proportion_preset
        focus_fit_method = 0,                     -- odaktaki sütunu ortala (Mango: prefer_center)
    },
})

-- 1–5 numaralı alanlar boşken de var olsun (adadaki noktalar için)
for i = 1, 5 do
    hl.workspace_rule({ workspace = tostring(i), persistent = true })
end

-- Etkin alanın düzenini değiştirir
local function set_layout(layout)
    local ws = hl.get_active_special_workspace() or hl.get_active_workspace()
    if not ws then
        return
    end
    -- Numaralı alan "1" diye seçilir; "name:1" adı "1" olan *adlandırılmış*
    -- alanı arar ve numaralı alana hiç uymaz (Super+N'nin çalışmama nedeni buydu)
    local selector
    if ws.special then
        selector = tostring(ws.name)
    elseif ws.id and ws.id > 0 then
        selector = tostring(ws.id)
    else
        selector = "name:" .. tostring(ws.name)
    end

    -- Aynı alan için verilen kural öncekinin yerine geçiyor; 1–5'in kalıcılığı kaybolmasın
    local keep = ws.id ~= nil and ws.id >= 1 and ws.id <= 5
    hl.workspace_rule({ workspace = selector, layout = layout, persistent = keep or nil })

    -- Bardaki ada, düzen adını yenilesin diye haber ver
    hl.dispatch(hl.dsp.event("desk-layout"))
end

-- Super+N: dwindle → scrolling → monocle → dwindle
local LAYOUT_CYCLE = { "dwindle", "scrolling", "monocle" }

local function cycle_layout()
    local ws = hl.get_active_special_workspace() or hl.get_active_workspace()
    if not ws then
        return
    end
    local next_layout = "dwindle"
    for i = 1, #LAYOUT_CYCLE do
        if LAYOUT_CYCLE[i] == ws.tiled_layout then
            next_layout = LAYOUT_CYCLE[(i % #LAYOUT_CYCLE) + 1]
            break
        end
    end
    set_layout(next_layout)
end

hl.bind("SUPER + N", cycle_layout)

-- desk'in Düzen menüsü bu ikisini çağırır:
--   hyprctl dispatch 'function() desk.set_layout("scrolling") end'
-- Böylece menü ile kısayollar aynı yoldan geçer.
desk = {
    set_layout = set_layout,
    cycle_layout = cycle_layout,
}

-- Super+Alt+D / S / M: doğrudan düzen seç (Mango: setlayout)
hl.bind("SUPER + ALT + D", function() set_layout("dwindle") end)
hl.bind("SUPER + ALT + S", function() set_layout("scrolling") end)
hl.bind("SUPER + ALT + M", function() set_layout("monocle") end)

-- Super+R: scrolling'de sütun genişliği 0.5 → 0.8 → 1.0 (Mango: switch_proportion_preset)
hl.bind("SUPER + R", function()
    local ws = hl.get_active_workspace()
    if ws and ws.tiled_layout == "scrolling" then
        hl.dispatch(hl.dsp.layout("colresize +conf"))
    end
end)

-- Super+C: scrolling'de odaktaki sütunu ekranın ortasına getir (Pencere menüsündeki "Sütunu ortala")
hl.bind("SUPER + C", function()
    local ws = hl.get_active_workspace()
    if ws and ws.tiled_layout == "scrolling" then
        hl.dispatch(hl.dsp.layout("center"))
    end
end)
