-- Klavye, dokunmatik yüzey, hareketler (Mango'daki değerler)

hl.config({
    input = {
        kb_layout = "tr",
        repeat_rate = 40,
        repeat_delay = 300,
        numlock_by_default = true,
        follow_mouse = 1,

        touchpad = {
            tap_to_click = true,
            disable_while_typing = true,
            natural_scroll = false,
        },
    },
})

-- Üç parmakla yatay kaydırma: çalışma alanı değiştir
hl.gesture({ fingers = 3, direction = "horizontal", action = "workspace" })
