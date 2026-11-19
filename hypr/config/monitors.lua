-- Ekranlar

-- desk'in çalışırken çağırdığı işler bu tabloda (hyprctl eval 'desk.…'); dosyalar ekler
desk = desk or {}

-- Dizüstü ekranı: 1080p, 144 Hz; pilde 60 Hz (desk.set_power → config/desk.lua)
desk.laptop = { output = "eDP-1", size = "1920x1080", refresh = 144, position = "0x0", scale = 1 }

function desk.set_refresh(hz)
    local l = desk.laptop
    hl.monitor({ output = l.output, mode = l.size .. "@" .. hz, position = l.position, scale = l.scale })
end

desk.set_refresh(desk.laptop.refresh)

-- Takılan diğer ekranlar: en iyi çözünürlük, sağa yerleşir
hl.monitor({ output = "", mode = "preferred", position = "auto", scale = 1 })
