-- Hyprland açılınca çalışanlar
-- EasyEffects ve polkit penceresi Home Manager servisleriyle başlıyor (home.nix).

-- desk (bar, dock, bildirimler…) ve hypridle (boşta karartma, kilit, uyku) burada değil: grafik
-- oturumla başlayan servisler, çökerlerse kendileri açılır (desk/nix/home.nix).
--   systemctl --user status desk      journalctl --user -u desk -f      systemctl --user restart desk

hl.on("hyprland.start", function()
    -- Hyprland açıkken kapağı systemd değil lid.sh yönetsin.
    -- Oturum kapanınca bu kilit de kalkar; giriş ekranında kapak kapanınca
    -- bilgisayar normal şekilde uyur (plan: Sorun 6).
    hl.exec_cmd("systemd-inhibit --what=handle-lid-switch --who=Hyprland --why='Lid handled by lid.sh' --mode=block sleep infinity")
end)
