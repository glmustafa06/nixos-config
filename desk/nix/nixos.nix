# desk'in sistem tarafı: Home Manager'ın yapamadığı, sistem düzeyindeki ayarlar.
#
# flake.nix → modules'e ./desk/nix/nixos.nix; configuration.nix'te: desk.enable = true;
# Kullanıcı tarafı (programlar, servisler): home.nix.
{ config, lib, pkgs, ... }:

{
  options.desk.enable = lib.mkEnableOption "desk'in sistem tarafı (kilit, pil, güç modu, yazı tipleri)";

  config = lib.mkIf config.desk.enable {
    # Kilit ekranlarının şifre denetimi: desk'in kilidi (desk-lock) ve yedek olarak hyprlock.
    # Bunlar olmadan desk sistemin giriş ayarını (login) kullanır; hyprlock hiç açılamaz (plan: Sorun 27).
    security.pam.services.desk-lock = { };
    security.pam.services.hyprlock = { };

    services.upower.enable = true; # pil: bar, kontrol merkezi, uyarılar, pilde hafif görünüm
    services.power-profiles-daemon.enable = true; # güç modu: Dengeli / Performans / Tasarruf

    fonts.packages = with pkgs; [
      inter # desk'in yazı tipi
      jetbrains-mono # kitty (theme/kitty/settings.conf)
    ];
  };
}
