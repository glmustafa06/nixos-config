# desk'in sistem tarafı: Home Manager'ın yapamadığı, sistem düzeyindeki ayarlar.
#
# flake.nix → modules'e ./desk/nix/nixos.nix; configuration.nix'te: desk.enable = true;
# Kullanıcı tarafı (programlar, servisler): home.nix.
{ config, lib, pkgs, ... }:

let
  cfg = config.desk;

  # Giriş ekranı teması (desk/sddm). Nix deposuna kopyalanır: temada değişiklik updatenix ister;
  # duvar kâğıdı ve kişi resmi ise /var/lib/desk'ten okunur (scripts/login_screen.py).
  sddmTheme = pkgs.runCommand "desk-sddm-theme" { } ''
    mkdir -p $out/share/sddm/themes
    cp -r ${../sddm} $out/share/sddm/themes/desk
  '';

  normalUsers = lib.attrNames (lib.filterAttrs (_: u: u.isNormalUser) config.users.users);
in
{
  options.desk = {
    enable = lib.mkEnableOption "desk'in sistem tarafı (kilit, giriş ekranı, pil, güç modu, yazı tipleri)";

    user = lib.mkOption {
      type = lib.types.str;
      default = if normalUsers == [ ] then "" else lib.head normalUsers;
      defaultText = "ilk normal kullanıcı";
      description = "desk'i kullanan kişi: giriş ekranının duvar kâğıdını o yazar (/var/lib/desk).";
    };

    loginScreen = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Giriş ekranı (SDDM) desk'in teması olsun: kilit ekranıyla aynı görünüm.";
    };
  };

  config = lib.mkIf cfg.enable (lib.mkMerge [
    {
      # Kilit ekranlarının şifre denetimi: desk'in kilidi (desk-lock) ve yedek olarak hyprlock.
      # Bunlar olmadan desk sistemin giriş ayarını (login) kullanır; hyprlock hiç açılamaz (plan: Sorun 27).
      security.pam.services.desk-lock = { };
      security.pam.services.hyprlock = { };

      services.upower.enable = true; # pil: bar, kontrol merkezi, uyarılar, pilde hafif görünüm
      services.power-profiles-daemon.enable = true; # güç modu: Dengeli / Performans / Tasarruf

      fonts.packages = with pkgs; [
        inter # desk'in yazı tipi (giriş ekranı da)
        jetbrains-mono # kitty (theme/kitty/settings.conf)
      ];
    }

    (lib.mkIf cfg.loginScreen {
      assertions = [{
        assertion = cfg.user != "";
        message = "desk.user boş: giriş ekranının duvar kâğıdını yazacak kullanıcıyı ver (desk.user = \"…\";).";
      }];

      # desk'in giriş ekranıyla paylaştıkları: kullanıcı yazar, SDDM (kendi kullanıcısıyla) okur
      systemd.tmpfiles.rules = [ "d /var/lib/desk 0755 ${cfg.user} users -" ];

      environment.systemPackages = [ sddmTheme ];
      services.displayManager.sddm.theme = "desk";
      # İlk açılışta (SDDM henüz hatırlamıyorken) desk'in çalıştığı oturum seçili gelsin
      services.displayManager.defaultSession = lib.mkDefault "hyprland-uwsm";
    })
  ]);
}
