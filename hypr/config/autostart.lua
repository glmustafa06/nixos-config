-- Hyprland açılınca çalışanlar
-- EasyEffects ve polkit penceresi Home Manager servisleriyle başlıyor (home.nix).

hl.on("hyprland.start", function()
    -- Geçici shell; Aşama 8'de kendi shell'imizle değişecek
    hl.exec_cmd("noctalia")

    -- Hyprland açıkken kapağı systemd değil lid.sh yönetsin.
    -- Oturum kapanınca bu kilit de kalkar; giriş ekranında kapak kapanınca
    -- bilgisayar normal şekilde uyur (plan: Sorun 6).
    hl.exec_cmd("systemd-inhibit --what=handle-lid-switch --who=Hyprland --why='Lid handled by lid.sh' --mode=block sleep infinity")
end)
