# desk'in Home Manager modülü: desk'in kullandığı programlar, desk ve hypridle servisleri,
# ~/.config/quickshell/desk bağlantısı ve ilk kurulum adımları.
#
# home.nix'te:
#   imports = [ ./desk/nix/home.nix ];
#   desk.enable = true;
#
# Sistem tarafı (kilit ekranının şifre denetimi, pil, güç modu, yazı tipleri) ayrı: nixos.nix.
{ config, lib, pkgs, ... }:

let
  cfg = config.desk;

  # desk'in ve betiklerinin çağırdığı programlar. Servisler bunları PATH'in başına ekler;
  # hyprctl, nmcli, systemctl, uwsm sistemden gelir (Hyprland'in hyprctl'ı çalışan Hyprland'le aynı
  # sürüm olmalı, o yüzden buraya konmaz).
  runtime = with pkgs; [
    quickshell
    matugen # duvar kâğıdından vurgu rengi
    imagemagick # duvar kâğıdının parlaklığını ölçer (bar, kilit ekranı)
    python3 # scripts/*.py
    procps # pgrep, pkill
    cliphist # pano geçmişi (Super+V)
    wl-clipboard
    grim # ekran görüntüsü
    slurp
    brightnessctl
    playerctl
    libnotify # notify-send
    xdg-utils # xdg-open: dock'taki İndirilenler, aramadaki dosyalar
    fd # aramada dosyalar
    hyprsunset # gece ışığı
    hypridle
  ];

  # Bluetooth eşleşme yardımcısının Python'u (scripts/bt_agent.py, D-Bus için dbus-next). Yalnızca
  # servislerin içinde; profile konmaz (home.nix'teki python3'le çakışmasın).
  agentPython = pkgs.python3.withPackages (ps: [ ps.dbus-next ]);

  withRuntime = name: command: pkgs.writeShellScript name ''
    export PATH=${lib.makeBinPath runtime}:$PATH
    export DESK_PYTHON=${agentPython}/bin/python3
    exec ${command}
  '';

  # Grafik oturumla başlayıp biten, çökünce kendini yeniden açan servis
  sessionService = description: command: {
    Unit = {
      Description = description;
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
      ConditionEnvironment = "WAYLAND_DISPLAY";
    };
    Service = {
      ExecStart = "${withRuntime "desk-${lib.head (lib.splitString " " command)}" command}";
      Restart = "on-failure";
      RestartSec = 2;
      # Yeniden başlarken yalnızca kendisi kapanır; açtıkları (kilit ekranı, uwsm'siz açılan
      # uygulamalar) yaşamaya devam eder.
      KillMode = "process";
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };
in
{
  options.desk = {
    enable = lib.mkEnableOption "desk: Hyprland + Quickshell masaüstü";

    source = lib.mkOption {
      type = lib.types.str;
      default = "${config.home.homeDirectory}/nixos-config/desk";
      description = ''
        desk'in klasörü. Nix deposuna kopyalanmaz, buradan çalışır: kaydettiğin an değişir.
        ~/.config/quickshell/desk buraya bağlanır; kısayollar ve kilit o yolu kullanır.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = runtime ++ (with pkgs; [
      hyprlock # yedek kilit (plan: Sorun 26)
      colloid-icon-theme # dock'un ve Dolphin'in simgeleri (Colloid-Dark)
      qt6Packages.qtstyleplugin-kvantum # Dolphin'in teması (Desk)
      # Dolphin'de önizlemeler (scripts/dolphin_setup.py açar)
      kdePackages.kdegraphics-thumbnailers # PDF, RAW
      kdePackages.ffmpegthumbs # video
      kdePackages.kimageformats # AVIF, HEIC, JXL, PSD…
      kdePackages.qtimageformats # WebP, TIFF
      xdg-terminal-exec # terminalde açılan uygulamalar (btop, nvim…) kitty'de açılsın
    ]);

    xdg.configFile."quickshell/desk".source = config.lib.file.mkOutOfStoreSymlink cfg.source;
    xdg.configFile."xdg-terminals.list".text = "kitty.desktop\n";

    # Pano geçmişi: kopyalananları cliphist'e kaydeder
    services.cliphist = {
      enable = true;
      allowImages = true;
    };

    # Günlük: journalctl --user -u desk -f      Yeniden başlat: systemctl --user restart desk
    systemd.user.services.desk = sessionService "desk: bar, dock, bildirimler, arama" "qs -c desk";

    # Boşta karartma, kilit, uyku (~/.config/hypr/hypridle.conf). Kilidi bu açar; çökerse kilit
    # ekranı açık kalır, hypridle birkaç saniyede geri gelir.
    systemd.user.services.hypridle = sessionService "hypridle: boşta karartma, kilit, uyku" "hypridle";

    # İlk kurulum (her updatenix'te; yalnızca eksik olanı tamamlar, kendi anahtarları dışında bir şeye
    # dokunmaz). Dolphin açıksa dolphin_setup.py kendini atlar; bir sonraki updatenix'te yapar.
    home.activation.desk = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      desk=${lib.escapeShellArg cfg.source}
      if [ -d "$desk/scripts" ]; then
        export PATH=${lib.makeBinPath (with pkgs; [ python3 procps coreutils gnugrep imagemagick ])}:$PATH
        kitty=${lib.escapeShellArg "${config.xdg.configHome}/kitty/kitty.conf"}
        if ! grep -qx 'include desk-colors.conf' "$kitty" 2>/dev/null; then
          run mkdir -p "$(dirname "$kitty")"
          run sh -c 'printf "\n# desk: renkler, yazı tipi, imleç (sonda kalsın; scripts/apps_theme.py)\ninclude desk-colors.conf\n" >> "$1"' sh "$kitty"
        fi
        run python3 "$desk/scripts/apps_theme.py" || echo "desk: apps_theme.py çalışmadı" >&2
        run python3 "$desk/scripts/dolphin_setup.py" || true
        # Giriş ekranı: duvar kâğıdı ve kişi resmi /var/lib/desk'e (ImageMagick gerekir)
        run python3 "$desk/scripts/login_screen.py" || true
      else
        echo "desk: $desk bulunamadı; ilk kurulum atlandı (desk.source)" >&2
      fi
    '';
  };
}
