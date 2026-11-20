{ config, pkgs, ... }:

{
  imports = [ ./hardware-configuration.nix ];

  # ---------------------------------------------------------------
  # Önyükleme
  # ---------------------------------------------------------------
  boot.loader.systemd-boot.enable = true;
  boot.loader.systemd-boot.configurationLimit = 5; # menüde en fazla 5 sürüm
  boot.loader.efi.canTouchEfiVariables = true;

  # Linux kernel latest'ta. Bir sorun çıkarsa linuxPackages yapılıp stable'a geçilebilir
  boot.kernelPackages = pkgs.linuxPackages_latest;

  # btrfs: zstd sıkıştırma + erişim zamanı yazmama.
  # hardware-configuration.nix'teki "subvol=..." seçenekleriyle birleşir.
  fileSystems = {
    "/".options = [ "compress=zstd" "noatime" ];
    "/home".options = [ "compress=zstd" "noatime" ];
    "/nix".options = [ "compress=zstd" "noatime" ];
  };

  # sda3: 384 GB'lık veri bölümü (btrfs) → ~/HDD
  # Büyük dosyalar burada durur, 40 GB'lık kök bölüm rahatlar.
  # Disk bulunamazsa açılış beklemez (nofail).
  fileSystems."/home/mustafa/HDD" = {
    device = "/dev/disk/by-uuid/89645538-1bb7-43e8-9f8e-257e0e3beedd";
    fsType = "btrfs";
    options = [ "noatime" "compress=zstd" "nofail" "x-systemd.device-timeout=5s" ];
  };

  zramSwap.enable = true;

  # ---------------------------------------------------------------
  # Saat, dil, klavye
  # ---------------------------------------------------------------
  time.timeZone = "Europe/Istanbul";
  # Windows aynı bilgisayarda: iki sistem arasında geçince saat 3 saat kaymasın.
  time.hardwareClockInLocalTime = true;

  i18n.defaultLocale = "en_US.UTF-8";
  i18n.extraLocaleSettings = {
    LC_TIME = "tr_TR.UTF-8";
    LC_MONETARY = "tr_TR.UTF-8";
    LC_MEASUREMENT = "tr_TR.UTF-8";
    LC_PAPER = "tr_TR.UTF-8";
    LC_ADDRESS = "tr_TR.UTF-8";
    LC_TELEPHONE = "tr_TR.UTF-8";
    LC_NAME = "tr_TR.UTF-8";
    LC_IDENTIFICATION = "tr_TR.UTF-8";
    # LC_NUMERIC ve LC_CTYPE bilerek İngilizce kalıyor: ondalık ayırıcı nokta olsun
    # ve Türkçe "I" sorunu betikleri bozmasın (plan: Sorun 19 ve 20).
  };

  services.xserver.xkb.layout = "tr";
  console.keyMap = "trq";

  desk.enable = true;

  # ---------------------------------------------------------------
  # Ağ, Bluetooth, güç
  # ---------------------------------------------------------------
  networking.hostName = "legion5";
  networking.networkmanager.enable = true;

  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
  };

  services.upower.enable = true;
  services.power-profiles-daemon.enable = true; # Güç modu: Dengeli / Performans / Tasarruf
  services.udisks2.enable = true; # Dolphin'den USB bellek bağlamak için

  # ---------------------------------------------------------------
  # Ses
  # ---------------------------------------------------------------
  security.rtkit.enable = true;
  security.pam.services.desk-lock = { };
  security.pam.services.hyprlock = { };
  
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    wireplumber.enable = true;
  };

  # ---------------------------------------------------------------
  # Grafik: AMD (ekran) + Nvidia RTX 2060 (gerektiğinde)
  # ---------------------------------------------------------------
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };

  services.xserver.videoDrivers = [ "nvidia" ];

  hardware.nvidia = {
    modesetting.enable = true;
    powerManagement.enable = false; # Uykudan uyanmada sorun çıkarsa ilk denenecek: true

    # Legion 5 (Ryzen 4000) ince ayarlı modu desteklemiyor; kaba mod kullanılıyor
    powerManagement.finegrained = false;
    moduleParams.nvidia.NVreg_DynamicPowerManagement = "0x01";
    open = false;
    nvidiaSettings = true;
    package = config.boot.kernelPackages.nvidiaPackages.production;

    prime = {
      offload = {
        enable = true;
        enableOffloadCmd = true; # "nvidia-offload <program>" komutu
      };
      amdgpuBusId = "PCI:5:0:0";
      nvidiaBusId = "PCI:1:0:0";
    };
  };

  # Ekran kartlarına sabit adlar (card0/card1 açılışta yer değiştirebiliyor)
  services.udev.extraRules = ''
    KERNEL=="card*", KERNELS=="0000:05:00.0", SUBSYSTEM=="drm", SUBSYSTEMS=="pci", SYMLINK+="dri/amd-igpu"
    KERNEL=="card*", KERNELS=="0000:01:00.0", SUBSYSTEM=="drm", SUBSYSTEMS=="pci", SYMLINK+="dri/nvidia-dgpu"

    # Nvidia sürücüye bağlanınca güç yönetimine izin ver (kaba mod için gerekli)
    ACTION=="bind", SUBSYSTEM=="pci", ATTR{vendor}=="0x10de", ATTR{class}=="0x030000", TEST=="power/control", ATTR{power/control}="auto"
    ACTION=="unbind", SUBSYSTEM=="pci", ATTR{vendor}=="0x10de", ATTR{class}=="0x030000", TEST=="power/control", ATTR{power/control}="on"
  '';

  # ---------------------------------------------------------------
  # Masaüstü: SDDM + Hyprland (UWSM ile)
  # ---------------------------------------------------------------
  services.displayManager.sddm = {
    enable = true;
    wayland.enable = true;
  };

  programs.hyprland = {
    enable = true;
    xwayland.enable = true;
    withUWSM = true;
  };

  # Dosya seçme pencereleri (Zen, Electron uygulamaları) için
  xdg.portal.extraPortals = [ pkgs.xdg-desktop-portal-gtk ];

  environment.sessionVariables = {
    NIXOS_OZONE_WL = "1"; # Electron uygulamaları Wayland'de açılsın
    QT_QPA_PLATFORMTHEME = "qt6ct"; # Dolphin'in koyu temada siyah yazı sorunu (CachyOS'taki çözüm)
  };

  programs.dconf.enable = true;

  # Nix dışından gelen hazır programlar (uv ile kurulan Python paketleri,
  # VS Code eklentileri) için
  programs.nix-ld.enable = true;

  # Oyunlar Windows'ta. Steam gerekirse aç; 40 GB'a dikkat (plan: Sorun 43).
  # programs.steam.enable = true;

  # ---------------------------------------------------------------
  # Yazı tipleri
  # ---------------------------------------------------------------
  fonts.packages = with pkgs; [
    inter
    jetbrains-mono
    nerd-fonts.jetbrains-mono
    noto-fonts
    noto-fonts-color-emoji
  ];

  fonts.fontconfig.defaultFonts = {
    sansSerif = [ "Inter" "Noto Sans" ];
    monospace = [ "JetBrains Mono" ];
    emoji = [ "Noto Color Emoji" ];
  };

  # ---------------------------------------------------------------
  # Kullanıcı
  # ---------------------------------------------------------------
  programs.fish.enable = true;

  users.users.mustafa = {
    isNormalUser = true;
    description = "Mustafa";
    shell = pkgs.fish;
    extraGroups = [ "wheel" "networkmanager" "video" "input" ];
  };

  environment.systemPackages = with pkgs; [
    git
    curl
    wget
    pciutils
    usbutils
    btrfs-progs
  ];

  # ---------------------------------------------------------------
  # Nix ve disk (40 GB kuralları — plan: Bölüm 2)
  # ---------------------------------------------------------------
  nixpkgs.config.allowUnfree = true;

  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
    # Nix indirme hızı ayarları
    http-connections = 50;
    max-substitution-jobs = 32;
    download-buffer-size = 512 * 1024 * 1024;

    # Boş yer 3 GB'ın altına inerse, derleme sırasında 8 GB boşalana kadar temizlik yap
    min-free = 3 * 1024 * 1024 * 1024;
    max-free = 8 * 1024 * 1024 * 1024;
  };

  # Aynı dosyaları birleştirme günde bir kez, arka planda
  nix.optimise.automatic = true;

  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 7d";
  };

  services.journald.settings.Journal.SystemMaxUse = "200M";

  system.stateVersion = "26.05";
}
