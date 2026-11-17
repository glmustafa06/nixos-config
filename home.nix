{ config, pkgs, inputs, ... }:

let
  # Nix'in dışında, git'te duran klasörleri ~/.config'e bağlar.
  # Dosyayı düzenlediğin an geçerli olur, rebuild gerekmez.
  link = path: config.lib.file.mkOutOfStoreSymlink "/home/mustafa/${path}";
in
{
  home.username = "mustafa";
  home.homeDirectory = "/home/mustafa";
  home.stateVersion = "26.05";

  home.packages = with pkgs; [
    # --- Masaüstü: Hyprland araçları + geçici shell (Noctalia) + kendi shell'imiz için Quickshell
    quickshell
    noctalia
    matugen
    hypridle
    hyprlock
    hyprsunset
    grim
    slurp
    wl-clipboard
    cliphist
    brightnessctl
    playerctl
    libnotify

    # --- Görünüm
    papirus-icon-theme
    adw-gtk3
    nwg-look
    qt6Packages.qt6ct
    qt6Packages.qtstyleplugin-kvantum
    kdePackages.breeze
    kdePackages.breeze-icons

    # --- Uygulamalar
    inputs.zen-browser.packages.${pkgs.stdenv.hostPlatform.system}.default
    kitty
    kdePackages.dolphin
    kdePackages.kio-extras
    vscode
    obsidian
    spotify
    onlyoffice-desktopeditors
    pavucontrol
    networkmanagerapplet # nm-connection-editor

    # --- Terminal araçları
    neovim
    btop
    fastfetch
    ripgrep
    fd
    fzf
    jq
    eza
    bat
    yazi
    ncdu
    unzip
    zip
    p7zip
    uv
    python3
    # gcc, rustc gibi derleyiciler sisteme değil, projeye özel `nix develop` ortamlarına
  ];

  # Hyprland ayarı: ~/nixos-config/hypr → ~/.config/hypr
  xdg.configFile."hypr".source = link "nixos-config/hypr";
  
  # Hyprland yalnızca AMD'yi kullansın, Nvidia uyuyabilsin.
  # HDMI'dan harici ekran takarsan sonuna :/dev/dri/nvidia-dgpu ekle
  # (HDMI büyük ihtimalle Nvidia'ya bağlı).
  xdg.configFile."uwsm/env-hyprland".text = ''
    export AQ_DRM_DEVICES=/dev/dri/amd-igpu
    export __EGL_VENDOR_LIBRARY_FILENAMES=/run/opengl-driver/share/glvnd/egl_vendor.d/50_mesa.json
  '';

  # Aşama 1'de açılacak: kendi shell'imiz
  # xdg.configFile."quickshell/yorunge".source = link "projects/yorunge";

  # İmleç
  home.pointerCursor = {
    enable = true;
    package = pkgs.bibata-cursors;
    name = "Bibata-Modern-Classic";
    size = 24;
    gtk.enable = true;
    x11.enable = true;
  };

  # Koyu tema tercihi (GTK uygulamaları)
  dconf.settings."org/gnome/desktop/interface".color-scheme = "prefer-dark";

  # Arka plan servisleri
  services.easyeffects.enable = true; # açılışta gizli başlar
  services.hyprpolkitagent.enable = true; # yönetici izni pencereleri

  # fish
  programs.fish = {
    enable = true;
    interactiveShellInit = ''
      set -g fish_greeting
    '';
    shellAliases = {
      updatenix = "sudo nixos-rebuild switch --flake ~/nixos-config#legion5"; # ayarı uygula
      flakeupdate = "nix flake update --flake ~/nixos-config"; # paket sürümlerini güncelle
      nixsize = "nixos-rebuild dry-build --flake ~/nixos-config#legion5"; # ne kadar inecek?
      nixclean = "sudo nix-collect-garbage --delete-older-than 7d"; # eski sürümleri sil
      cdnix = "cd ~/nixos-config";
      prime-run = "env __EGL_VENDOR_LIBRARY_FILENAMES=/run/opengl-driver/share/glvnd/egl_vendor.d/10_nvidia.json:/run/opengl-driver/share/glvnd/egl_vendor.d/50_mesa.json nvidia-offload";
    };
  };

  # kitty.conf, Noctalia, qt6ct ve EasyEffects ayarları bilerek Nix'e verilmedi:
  # arayüzden ya da Noctalia tarafından değiştiriliyorlar (plan: Sorun 40).
}
