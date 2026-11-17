-- Ortam değişkenleri

hl.env("XCURSOR_THEME", "Bibata-Modern-Classic")
hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")
hl.env("ELECTRON_OZONE_PLATFORM_HINT", "auto")

-- GPU seçimi (plan: Sorun 4).
-- İlk açılışta `cat /sys/bus/pci/devices/0000:01:00.0/power/runtime_status`
-- "active" kalıyorsa, AMD'yi öne alan satır buraya eklenecek.
-- hl.env("AQ_DRM_DEVICES", "/dev/dri/amd-igpu:/dev/dri/nvidia-dgpu")
