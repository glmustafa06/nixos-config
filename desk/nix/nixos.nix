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

  # Pil koruma (Ayarlar → Pil ve güç): şarjı erken durduran dosyalar yalnızca root'a yazılabilir.
  # Aygıt gelince "users" grubuna (normal kullanıcıların grubu) yazma izni verilir.
  #   Lenovo (Legion, IdeaPad): conservation_mode   ötekiler: charge_control_end_threshold
  batteryAccess = pkgs.writeShellScript "desk-battery-access" ''
    for name in conservation_mode charge_control_end_threshold charge_control_start_threshold; do
      file="$1/$name"
      if [ -e "$file" ]; then
        ${pkgs.coreutils}/bin/chgrp users "$file"
        ${pkgs.coreutils}/bin/chmod g+w "$file"
      fi
    done
  '';
in
{
  options.desk = {
    enable = lib.mkEnableOption "desk'in sistem tarafı (kilit, giriş ekranı, pil, güç modu, yazı tipleri, ekran kaydı izni)";

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

    loginCompositor = lib.mkOption {
      type = lib.types.enum [ "kwin" "weston" ];
      default = "kwin";
      description = ''
        Giriş ekranını çizen program. NixOS'un varsayılanı Weston; bu bilgisayarda (AMD + Nvidia) fare çalıştığı
        hâlde imleci çizmiyor (plan: Sorun 94). KWin (KDE'nin giriş ekranında kullandığı) çiziyor; birkaç yüz MB
        daha yer tutar. Klavye düzeni (tr) ikisinde de services.xserver.xkb'den gelir.
      '';
    };

    # İmleç teması: giriş ekranında ve sistemde varsayılan (oturumdaki home.nix → home.pointerCursor ile aynı olmalı)
    cursor = {
      name = lib.mkOption {
        type = lib.types.str;
        default = "Bibata-Modern-Classic";
        description = "İmleç temasının adı.";
      };
      package = lib.mkOption {
        type = lib.types.package;
        default = pkgs.bibata-cursors;
        defaultText = lib.literalExpression "pkgs.bibata-cursors";
        description = "İmleç temasının paketi.";
      };
      size = lib.mkOption {
        type = lib.types.int;
        default = 24;
        description = "İmlecin boyu.";
      };
    };
  };

  config = lib.mkIf cfg.enable (lib.mkMerge [
    {
      # Kilit ekranlarının şifre denetimi: desk'in kilidi (desk-lock) ve yedek olarak hyprlock.
      # Bunlar olmadan desk sistemin giriş ayarını (login) kullanır; hyprlock hiç açılamaz (plan: Sorun 27).
      security.pam.services.desk-lock = { };
      security.pam.services.hyprlock = { };

      services.upower.enable = true; # pil: bar, kontrol merkezi, uyarılar, pilde hafif görünüm
      # Ekran kaydı (Print → Kayıt): ekranı ekran kartından okuması için izinli yardımcı (gsr-kms-server)
      programs.gpu-screen-recorder.enable = true;
      services.power-profiles-daemon.enable = true; # güç modu: Dengeli / Performans / Tasarruf
      services.udev.extraRules = ''
        ACTION=="add|bind", SUBSYSTEM=="platform", DRIVER=="ideapad_acpi", RUN+="${batteryAccess} /sys%p"
        ACTION=="add", SUBSYSTEM=="power_supply", KERNEL=="BAT*", RUN+="${batteryAccess} /sys%p"
      '';

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

      environment.systemPackages = [ sddmTheme cfg.cursor.package ];
      services.displayManager.sddm.theme = "desk";
      # İmleç: NixOS imleç temasını yalnızca Breeze temasında kendisi verir; vermezse SDDM'in Wayland
      # ekranında imleç görünmez (bulunamayan "default" tema). Ayrıca sistemde temasını bilmeyen
      # programlar için de varsayılan ("default" bu temayı miras alır).
      services.displayManager.sddm.settings.Theme = {
        CursorTheme = lib.mkDefault cfg.cursor.name;
        CursorSize = lib.mkDefault cfg.cursor.size;
      };
      xdg.icons.fallbackCursorThemes = lib.mkDefault [ cfg.cursor.name ];
      # Giriş ekranını çizen program (Wayland açıksa; configuration.nix → sddm.wayland.enable)
      services.displayManager.sddm.wayland.compositor = lib.mkDefault cfg.loginCompositor;
      # İlk açılışta (SDDM henüz hatırlamıyorken) desk'in çalıştığı oturum seçili gelsin
      services.displayManager.defaultSession = lib.mkDefault "hyprland-uwsm";
    })
  ]);
}
