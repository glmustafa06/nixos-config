-- Hyprland açılınca çalışanlar
-- EasyEffects ve polkit penceresi Home Manager servisleriyle başlıyor (home.nix).

hl.on("hyprland.start", function()
    -- Kendi shell'imiz: duvar kâğıdı, bar, dock, bildirimler, arama, kontrol merkezi.
    -- -n: zaten çalışıyorsa ikincisini açma. Dosyaları kaydettikçe kendini yeniler.
    hl.exec_cmd("qs -n -p ~/nixos-config/desk")

    -- Boşta kalınca karartma, kilit, uyku; loginctl lock-session gelince desk'in kilidi
    -- (hypridle.conf). Noctalia Aşama 8'de çıktı.
    hl.exec_cmd("hypridle")

    -- Hyprland açıkken kapağı systemd değil lid.sh yönetsin.
    -- Oturum kapanınca bu kilit de kalkar; giriş ekranında kapak kapanınca
    -- bilgisayar normal şekilde uyur (plan: Sorun 6).
    hl.exec_cmd(
        "systemd-inhibit --what=handle-lid-switch --who=Hyprland --why='Lid handled by lid.sh' --mode=block sleep infinity")
end)
