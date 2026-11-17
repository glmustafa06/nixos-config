-- Ekranlar

-- Dizüstü ekranı: 1080p, 144 Hz
hl.monitor({ output = "eDP-1", mode = "1920x1080@144", position = "0x0", scale = 1 })

-- Takılan diğer ekranlar: en iyi çözünürlük, sağa yerleşir
hl.monitor({ output = "", mode = "preferred", position = "auto", scale = 1 })
