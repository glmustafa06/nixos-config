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
  
  imports = [ ./desk/nix/home.nix ];
  desk.enable = true;

  home.packages = with pkgs; [
    # --- Masaüstü: Hyprland araçları + geçici shell (Noctalia) + kendi shell'imiz için Quickshell
    quickshell
    matugen
    imagemagick
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
    xdg-utils

    # --- Görünüm
    papirus-icon-theme
    colloid-icon-theme
    adw-gtk3
    nwg-look
    qt6Packages.qt6ct
    qt6Packages.qtstyleplugin-kvantum
    kdePackages.breeze
    kdePackages.breeze-icons

    # --- Uygulamalar
    inputs.zen-browser.packages.${pkgs.stdenv.hostPlatform.system}.default
    firefox
    kitty
    kdePackages.dolphin
    kdePackages.kio-extras
    kdePackages.kdegraphics-thumbnailers # Dolphin'de PDF ve RAW önizlemeleri
    kdePackages.ffmpegthumbs # video önizlemeleri
    kdePackages.kimageformats # AVIF, HEIC, JXL, PSD… resimleri ve önizlemeleri
    kdePackages.qtimageformats # WebP, TIFF
    vscode
    obsidian
    spotify
    onlyoffice-desktopeditors
    pavucontrol
    vlc

    # --- Terminal araçları
    neovim
    vim
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
    tree
    python3
    gh
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
  services.cliphist = {
    enable = true;
    allowImages = true;
  };

  # Starship ayarları (terminal)
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
