# ═══════════════════════════════════════════════════════════════════════════
# home.nix — kullanıcı tarafı (Home Manager)
# ═══════════════════════════════════════════════════════════════════════════
#
# Bu dosya ne?
#   Senin kullanıcına ait olanlar: kurulu programlar, ~/.config'teki dosyalar, kullanıcı servisleri
#   (oturumla başlayan programlar), fish ayarları. Sistem tarafı configuration.nix'te.
#
# Nasıl çalışır?
#   Home Manager bu dosyadan bir "ev" sürümü üretir ve onu evine yerleştirir:
#     - home.packages               → /etc/profiles/per-user/mustafa/bin (PATH'te)
#     - xdg.configFile."x"          → ~/.config/x (Nix deposundaki dosyaya bağlantı, salt okunur)
#     - systemd.user.services, services.* → ~/.config/systemd/user (kullanıcı servisleri)
#     - home.sessionVariables vb.   → oturum açılırken okunan ortam değişkenleri
#   Yönettiği bir dosyayı elle değiştiremezsin (salt okunur); değiştirmek için buradan.
#
# Ne zaman devreye girer?
#   updatenix'te ve her açılışta home-manager-mustafa servisi çalışıp dosyaları yerleştirir
#   (flake.nix'te Home Manager NixOS'un içine yerleştirildiği için ayrı bir komut yok).
#   Kullanıcı servisleri oturum açılınca başlar; ortam değişkenleri oturumu kapatıp açınca değişir.
#   Hata olursa: journalctl -u home-manager-mustafa

{ config, pkgs, inputs, ... }:
# config: Home Manager'ın birleşmiş ayar ağacı; pkgs: sistemle aynı nixpkgs;
# inputs: flake.nix'teki girişler (zen-browser için).

let
  # Nix'in dışında, git'te duran klasörleri ~/.config'e bağlar (mkOutOfStoreSymlink).
  # Normal bir "source = ./klasör" klasörü Nix deposuna kopyalar: salt okunur olur, her değişiklik
  # updatenix ister. Bu ise doğrudan ~/nixos-config'teki klasörü gösterir: dosyayı düzenlediğin an
  # geçerli olur, rebuild gerekmez.
  link = path: config.lib.file.mkOutOfStoreSymlink "/home/mustafa/${path}";
in
{
  home.username = "mustafa";
  home.homeDirectory = "/home/mustafa";
  # Home Manager'ın ilk kurulduğu sürüm; bazı varsayılanlar buna göre seçilir. Değiştirilmez.
  home.stateVersion = "26.05";

  # desk'in kullanıcı tarafı (desk/nix/home.nix). Getirdikleri:
  #   - desk'in kullandığı programlar: quickshell, matugen, grim, slurp, satty, cliphist, wl-clipboard,
  #     brightnessctl, playerctl, hypridle, hyprlock, hyprsunset, Colloid simgeleri, Kvantum,
  #     Dolphin önizleme eklentileri…
  #   - servisler: desk (bar, dock, bildirimler; "qs -c desk"), hypridle, cliphist (pano geçmişi)
  #   - ~/.config/quickshell/desk → ~/nixos-config/desk bağlantısı
  #   - her updatenix'te ilk kurulum betikleri (renkler, Dolphin ayarları, giriş ekranı resmi)
  # Bunları burada tekrar yazmaya gerek yok.
  imports = [ ./desk/nix/home.nix ];
  desk.enable = true;

  # ---------------------------------------------------------------
  # Programlar
  # ---------------------------------------------------------------
  # Silmek için satırı sil + updatenix. Dosyaları /nix/store'da bir süre daha durur, nix.gc temizler.
  # desk'in kullandığı programlar burada yok, desk/nix/home.nix kuruyor (yukarıdaki imports).
  home.packages = with pkgs; [
    # --- Görünüm
    qt6Packages.qt6ct # Qt programlarının görünüm ayarları penceresi (configuration.nix → QT_QPA_PLATFORMTHEME)
    kdePackages.breeze # KDE'nin Qt stili: Kvantum yüklenemezse KDE programları bunu kullanır
    kdePackages.breeze-icons # KDE programlarının yedek simgeleri (Colloid'de bulunmayanlar)
    # Aşağıdaki üçü Noctalia döneminden; desk bunları kullanmıyor. Ama GTK ya da Qt ayarlarında
    # seçiliyse programlar hâlâ kullanıyor olabilir. Kontrol:
    #   gsettings get org.gnome.desktop.interface gtk-theme; gsettings get org.gnome.desktop.interface icon-theme
    #   grep -i theme ~/.config/gtk-3.0/settings.ini ~/.config/qt6ct/qt6ct.conf
    # Çıktılarda "Papirus" ya da "adw-gtk3" geçmiyorsa üçü de silinebilir.
    papirus-icon-theme # simge teması (desk ve Dolphin Colloid kullanıyor)
    adw-gtk3 # GTK3 programlarına GNOME'un yeni (libadwaita) görünümü
    nwg-look # GTK temasını, simgeleri, imleci seçen pencere (~/.config/gtk-3.0 ve gsettings'e yazar)

    # --- Uygulamalar
    inputs.zen-browser.packages.${pkgs.stdenv.hostPlatform.system}.default # Zen (flake.nix → inputs)
    firefox # Zen'in yanında yedek tarayıcı; kullanmıyorsan silinebilir
    kitty # terminal; ayarı ~/.config/kitty/kitty.conf (Nix dışında, en alttaki nota bak)
    kdePackages.dolphin # dosya yöneticisi
    kdePackages.kio-extras # Dolphin'in ek yetenekleri: önizlemeler, arşivlerin içi, ağ (sftp, smb)
    # (Dolphin'in PDF, video, resim önizleme eklentileri desk'ten geliyor.)
    vscode
    obsidian
    spotify
    onlyoffice-desktopeditors
    pavucontrol # ses aygıtlarını ve programların sesini ayrıntılı ayarlama penceresi
    vlc

    # --- Neovim
    neovim
    # Mason (Neovim'in dil sunucusu kurucusu, ~/.local/share/nvim/mason) kurduklarını Nix'ten değil
    # internetten indirir ve kurarken sistemdeki araçları kullanır:
    #   - bash-language-server (bashls), pyright gibi çoğu npm paketi: npm ve node bu pakette.
    #     Yokken Mason "failed to install bashls" diyordu.
    #   - hazır derlenmiş olanlar (lua-language-server gibi) configuration.nix'teki nix-ld sayesinde çalışır.
    nodejs
    vim # neovim'in yanında; alışkanlıksa kalsın, değilse silinebilir

    # --- Terminal araçları
    btop # sistem izleyici (işlemci, bellek, süreçler)
    fastfetch # sistem özeti
    ripgrep # rg: dosyaların içinde hızlı arama
    fd # dosya adıyla hızlı arama (desk de kuruyor; terminalde kendin kullandığın için burada da)
    fzf # bulanık seçici: bir listeden yazarak seçme (örnek: ls | fzf)
    jq # JSON okuma/süzme
    eza # renkli, simgeli ls
    bat # renkli cat
    yazi # terminalde dosya yöneticisi
    ncdu # hangi klasör ne kadar yer kaplıyor
    unzip
    zip
    p7zip # 7z
    uv # Python sürümleri, sanal ortamlar ve paketler
    tree
    python3 # (desk de kuruyor; terminalde kendin kullandığın için burada da)
    gh # GitHub komut satırı
    # gcc, rustc gibi derleyiciler sisteme değil, projeye özel `nix develop` ortamlarına
  ];

  # ---------------------------------------------------------------
  # Hyprland
  # ---------------------------------------------------------------
  # ~/.config/hypr → ~/nixos-config/hypr (yukarıdaki link). Hyprland ayar dosyası değişince
  # kendini yeniden yükler (olmazsa: hyprctl reload).
  xdg.configFile."hypr".source = link "nixos-config/hypr";

  # uwsm'in Hyprland'i başlatmadan hemen önce okuduğu dosya (~/.config/uwsm/env-hyprland). Buradaki
  # değişkenler Hyprland'e ve onun açtığı her programa geçer. Hyprland'in kendi ayar dosyasına
  # (hypr/config/env.lua) konamazlardı: Hyprland ekran kartını o dosyayı okumadan önce seçiyor.
  #   AQ_DRM_DEVICES: Hyprland (Aquamarine) yalnızca AMD kartını kullansın, Nvidia uyuyabilsin.
  #                   (/dev/dri/amd-igpu adı configuration.nix'teki udev kuralından.)
  #   __EGL_VENDOR_LIBRARY_FILENAMES: programlar OpenGL için yalnızca Mesa'yı (AMD) yüklesin; Nvidia'nın
  #                   kütüphanesini açıp kartı uyandırmasınlar. Nvidia'da çalıştırmak için: prime-run (aşağıda).
  # Ne zaman: oturum açılırken.
  # HDMI'dan harici ekran takarsan AQ_DRM_DEVICES'in sonuna :/dev/dri/nvidia-dgpu ekle
  # (HDMI büyük ihtimalle Nvidia'ya bağlı).
  xdg.configFile."uwsm/env-hyprland".text = ''
    export AQ_DRM_DEVICES=/dev/dri/amd-igpu
    export __EGL_VENDOR_LIBRARY_FILENAMES=/run/opengl-driver/share/glvnd/egl_vendor.d/50_mesa.json
  '';

  # ---------------------------------------------------------------
  # Görünüm
  # ---------------------------------------------------------------
  # İmleç teması. XCURSOR_THEME ve XCURSOR_SIZE değişkenlerini ayarlar, imleç dosyalarını
  # ~/.local/share/icons'a bağlar; programlar imleci buradan bulur. Giriş ekranındaki imleç ayrı:
  # desk/nix/nixos.nix → desk.cursor (aynı tema, aynı boy olmalı). Hyprland'in kendi değişkenleri
  # hypr/config/env.lua'da.
  #   gtk.enable: Home Manager GTK ayar dosyalarını yazsaydı imleci de oraya koyardı; o yazma kapalı
  #               (gtk.enable yok), bu yüzden şu an bir şey değiştirmiyor.
  #   x11.enable: ~/.Xresources'a yazar; yalnızca X oturumları okur.
  home.pointerCursor = {
    enable = true;
    package = pkgs.bibata-cursors;
    name = "Bibata-Modern-Classic";
    size = 24;
    gtk.enable = true;
    x11.enable = true;
  };

  # Koyu tema tercihi: GTK4/libadwaita programları ve tarayıcıların "koyu mod"u buna bakar
  # (dconf veritabanına yazılır; configuration.nix → programs.dconf).
  dconf.settings."org/gnome/desktop/interface".color-scheme = "prefer-dark";

  # ---------------------------------------------------------------
  # Oturumla başlayan servisler
  # ---------------------------------------------------------------
  # Hepsi graphical-session.target'a bağlı: Hyprland açılınca başlar, çıkışta kapanır.
  # Kontrol: systemctl --user status easyeffects
  services.easyeffects.enable = true; # ses efektleri (ekolayzer); açılışta gizli başlar
  services.hyprpolkitagent.enable = true; # yönetici izni isteyen işlemlerde şifre penceresi
  # Pano geçmişi (cliphist) desk'ten geliyor (desk/nix/home.nix).

  # ---------------------------------------------------------------
  # Terminal: starship ve fish
  # ---------------------------------------------------------------
  # Starship: terminaldeki komut satırının başı (klasör, git dalı, Python ortamı, süre, hata kodu).
  # Ayarları ~/.config/starship.toml'a yazılır; fish'e Home Manager bağlar.
  programs.starship = {
    enable = true;
    settings = {
      add_newline = true;
      format = "$directory$git_branch$git_state$git_status$python$nix_shell$cmd_duration$status$character";
      directory = { style = "bold cyan"; truncation_length = 3; truncate_to_repo = true; read_only = " 󰌾"; };
      git_branch = { symbol = " "; style = "purple"; format = "[$symbol$branch]($style) "; };
      git_status = { style = "yellow"; format = "([$all_status$ahead_behind]($style) )"; };
      python = { style = "green"; format = "[(\\($virtualenv\\) )]($style)"; };
      nix_shell = { style = "blue"; format = "[nix( $name)]($style) "; };
      cmd_duration = { min_time = 2000; style = "yellow"; format = "[$duration]($style) "; };
      status = { disabled = false; style = "red"; format = "[✗ $status]($style) "; };
      character = { success_symbol = "[❯](bold green)"; error_symbol = "[❯](bold red)"; };
    };
  };

  # fish: ~/.config/fish/config.fish'i Home Manager yazar (elle değiştirme; buradan).
  # Kabuğun kendisi configuration.nix'te (users.users.mustafa.shell).
  programs.fish = {
    enable = true;
    # Etkileşimli her terminal açılışında çalışır. fish_greeting boş: karşılama yazısı çıkmasın.
    interactiveShellInit = ''
      set -g fish_greeting
    '';
    # Takma adlar: soldaki yazılınca sağdaki çalışır.
    shellAliases = {
      updatenix = "sudo nixos-rebuild switch --flake ~/nixos-config#legion5"; # ayarı uygula
      flakeupdate = "nix flake update --flake ~/nixos-config"; # paket sürümlerini güncelle
      nixsize = "nixos-rebuild dry-build --flake ~/nixos-config#legion5"; # ne kadar inecek?
      nixclean = "sudo nix-collect-garbage --delete-older-than 7d"; # eski sürümleri sil
      cdnix = "cd ~/nixos-config";
      # Bir programı Nvidia'da çalıştır: "prime-run program". nvidia-offload (configuration.nix)
      # Nvidia'yı seçer; EGL listesine Nvidia'yı da geri ekler (env-hyprland yalnızca Mesa bırakıyor).
      prime-run = "env __EGL_VENDOR_LIBRARY_FILENAMES=/run/opengl-driver/share/glvnd/egl_vendor.d/10_nvidia.json:/run/opengl-driver/share/glvnd/egl_vendor.d/50_mesa.json nvidia-offload";
    };
  };

  # kitty.conf, qt6ct ve EasyEffects ayarları bilerek Nix'e verilmedi: kendi pencerelerinden
  # değiştiriliyorlar; Nix'e verilseydi salt okunur olurlardı (plan: Sorun 40). kitty.conf'un sonuna
  # desk renkleri için tek bir satır ekler (desk/nix/home.nix → home.activation.desk).
}
