-- Hyprland açılınca çalışanlar
-- EasyEffects ve polkit penceresi Home Manager servisleriyle başlıyor (home.nix).

hl.on("hyprland.start", function()
    -- Kendi shell'imiz: üst bar ve ada.
    -- -n: zaten çalışıyorsa ikincisini açma. Dosyaları kaydettikçe kendini yeniler.
    hl.exec_cmd("qs -n -p ~/projects/desk")

    -- Geçici: kontrol merkezi, başlatıcı, bildirimler, kilit, duvar kâğıdı.
    -- desk bu parçaları yazdıkça azalacak, Aşama 8'de tamamen çıkacak.
    hl.exec_cmd("noctalia")

    -- Hyprland açıkken kapağı systemd değil lid.sh yönetsin.
    -- Oturum kapanınca bu kilit de kalkar; giriş ekranında kapak kapanınca
    -- bilgisayar normal şekilde uyur (plan: Sorun 6).
    hl.exec_cmd("systemd-inhibit --what=handle-lid-switch --who=Hyprland --why='Lid handled by lid.sh' --mode=block sleep infinity")
end)
