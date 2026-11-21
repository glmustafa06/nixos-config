# ═══════════════════════════════════════════════════════════════════════════
# configuration.nix — sistemin kendisi (NixOS)
# ═══════════════════════════════════════════════════════════════════════════
#
# Bu dosya ne?
#   Bilgisayarın sistem tarafı: önyükleme, çekirdek, diskler, saat ve dil, ağ, ses, ekran kartları,
#   giriş ekranı, kullanıcı hesabı ve Nix'in kendi ayarları. Root yetkisi isteyen her şey burada.
#   Kullanıcıya ait olanlar (programlar, ~/.config dosyaları, kullanıcı servisleri) home.nix'te.
#
# Nereden okunur?
#   flake.nix → nixosConfigurations.legion5 → modules listesi. Aynı listede desk/nix/nixos.nix ve
#   Home Manager da var. NixOS hepsini tek bir ayar ağacında birleştirir:
#     - aynı liste iki dosyada yazılırsa (paketler, yazı tipleri) uç uca eklenir;
#     - tek değerli bir ayar (açık/kapalı, bir yazı) iki dosyada yazılırsa değerler aynı olmalı,
#       farklıysa updatenix "conflicting definition values" hatası verir.
#
# Ne zaman devreye girer?
#   updatenix (= sudo nixos-rebuild switch --flake ~/nixos-config#legion5):
#     1. Nix bu dosyaları okur ve bütün sistemi tarif eden bir "derivation" hesaplar.
#     2. Eksik olanları indirir ya da derler; sonuç /nix/store'a girer (eski sürüm silinmez).
#     3. Yeni sürüm /run/current-system olur: /etc yeniden yazılır, ayarı değişen servisler yeniden
#        başlar, açılış menüsüne yeni bir satır eklenir.
#   Bazı ayarlar ancak yeniden başlatınca (çekirdek, initrd, dosya sistemleri), bazıları da oturumu
#   kapatıp açınca (ortam değişkenleri, kullanıcı grupları) geçerli olur. Her bölümde yazıyor.
#
# Bir şey bozulursa: açılıştaki menüden bir önceki sürümü seç. Sürümler /nix/store'da durduğu
# için geri dönmek anlıktır; sonra bu dosyayı düzeltip updatenix.
#
# Not: Satır sonundaki "# …" ve "#" ile başlayan satırlar açıklamadır, Nix bunları okumaz.

{ config, pkgs, ... }:
# Yukarıdaki satır: bu dosya bir fonksiyon. NixOS onu çağırırken ona verir:
#   config: birleşmiş ayar ağacının tamamı (başka dosyalarda yazılanları okumak için)
#   pkgs:   nixpkgs'teki bütün paketler (flake.lock'taki sürüm)

{
  # Donanıma özel kısım (diskler, initrd modülleri, işlemci mikrokodu): kurulumda
  # nixos-generate-config üretti. Açıklamaları kendi içinde.
  imports = [ ./hardware-configuration.nix ];

  # ---------------------------------------------------------------
  # Önyükleme
  # ---------------------------------------------------------------
  # Açılış sırası:
  #   UEFI → systemd-boot (sürüm menüsü, /boot'ta) → Linux çekirdeği + initrd
  #   → initrd diski bulup kök bölümü bağlar → systemd (sistem servisleri) → SDDM (giriş ekranı)
  #   → Hyprland (uwsm ile) → desk ve öteki kullanıcı servisleri
  # Bu bölüm ilk üç halkayı ayarlar. updatenix'le yazılır, bir sonraki açılışta görülür.

  # systemd-boot: açılışta sürümleri listeleyen menü (varsayılan: 5 saniye bekler). Windows aynı EFI
  # bölümündeyse menüde kendiliğinden görünür; değilse BIOS'un açılış menüsünden (F12) seçilir.
  boot.loader.systemd-boot.enable = true;
  # Menüde en fazla 5 sürüm: her sürümün çekirdeği ve initrd'si küçük /boot bölümüne kopyalanır,
  # dolmasın. Daha eski sürümler /nix/store'da kalır, nix.gc (aşağıda) silene kadar.
  boot.loader.systemd-boot.configurationLimit = 5;
  # NixOS, UEFI'nin açılış listesine "Linux Boot Manager" kaydını kendisi yazabilsin.
  boot.loader.efi.canTouchEfiVariables = true;

  # Linux çekirdeği. boot.kernelPackages yalnızca çekirdeği değil, ona göre derlenen modülleri de
  # (NVIDIA sürücüsü gibi) seçer.
  # pkgs.linuxPackages: nixpkgs'in varsayılanı, uzun süre desteklenen (LTS) sürüm.
  # Neden en yenisi (linuxPackages_latest) değil: NVIDIA sürücüsü kapalı kaynak olduğu için Nix'in
  # hazır paket önbelleğinde yok, her çekirdek güncellemesinde bu bilgisayarda yeniden derleniyor.
  # En yeni çekirdeğe büyük sürüm geldiğinde sürücü bazen birkaç gün derlenmiyor ve updatenix hata
  # veriyor. LTS'te bu nadir; bu donanıma (Ryzen 4000, RTX 2060) en yeni çekirdeğin getirdiği bir şey yok.
  # Ne zaman: bir sonraki açılışta.   Kontrol: uname -r
  boot.kernelPackages = pkgs.linuxPackages;

  # ---------------------------------------------------------------
  # Diskler
  # ---------------------------------------------------------------
  # Ana bölüm (40 GB) tek bir btrfs; içinde üç alt birim (subvolume): @ → /, @home → /home, @nix → /nix.
  # Hangisinin nereye bağlanacağı hardware-configuration.nix'te ("subvol=@" …). Buradaki seçenekler
  # oradakilerle birleşir (liste oldukları için uç uca eklenir).
  #   compress=zstd: yeni yazılan dosyalar sıkıştırılır, yer kazandırır (var olan dosyalar değişmez)
  #   noatime: bir dosya her okunduğunda "son erişim zamanı" diske yazılmaz (gereksiz yazma)
  # Aynı diskteki alt birimler çoğu btrfs seçeneğini paylaşır; üçüne aynısını yazmak en temizi.
  # Ne zaman: açılışta bağlanırken.   Kontrol: findmnt -t btrfs
  fileSystems = {
    "/".options = [ "compress=zstd" "noatime" ];
    "/home".options = [ "compress=zstd" "noatime" ];
    "/nix".options = [ "compress=zstd" "noatime" ];
  };

  # sda3: 384 GB'lık veri bölümü (btrfs) → ~/HDD
  # Büyük dosyalar burada durur, 40 GB'lık ana bölüm rahatlar.
  #   device: bölümün kimliği (UUID); "lsblk -f" ile görülür. sda/sdb adı açılışta değişebilir, UUID değişmez.
  #   nofail: disk yoksa ya da bozuksa açılış durmaz, yalnızca bu klasör boş kalır.
  #   x-systemd.device-timeout=5s: açılışta diski 5 saniye bekler (varsayılan 90 saniye).
  fileSystems."/home/mustafa/HDD" = {
    device = "/dev/disk/by-uuid/89645538-1bb7-43e8-9f8e-257e0e3beedd";
    fsType = "btrfs";
    options = [ "noatime" "compress=zstd" "nofail" "x-systemd.device-timeout=5s" ];
  };

  # Takas alanı (swap) diskte değil, RAM'de ve sıkıştırılmış (zram): bellek dolunca az kullanılan
  # sayfalar sıkıştırılıp RAM'de tutulur. Varsayılan boyut RAM'in yarısı, sıkıştırma zstd.
  # Diskte takas olmadığı için hazırda bekletme (hibernate) yok; uyku (suspend) bundan etkilenmez.
  # Kontrol: zramctl
  zramSwap.enable = true;

  # ---------------------------------------------------------------
  # Saat, dil, klavye
  # ---------------------------------------------------------------
  # Saat dilimi: /etc/localtime bu bölgeyi gösterir.   Kontrol: timedatectl
  time.timeZone = "Europe/Istanbul";

  # Donanım saati (anakarttaki pilli saat, RTC) UTC'de tutulur; Linux'un beklediği bu.
  # Önceden true idi (Windows'un alışkanlığı: RTC'de yerel saat). Ama saati açılışta buna göre
  # düzelten adım initrd'deki systemd'de ve NixOS'un systemd initrd'sine bu bilgi (/etc/adjtime)
  # konmuyor: çekirdek RTC'yi UTC sanıp saati 3 saat ileri kuruyordu, internet gelince NTP
  # düzeltiyordu (internetsiz açılışta saat yanlış kalıyordu).
  # Windows'un da RTC'yi UTC okuması için Windows'ta, yönetici olarak açılmış Komut İstemi'nde
  # (bir kez; Windows yeniden kurulursa tekrar):
  #   reg add "HKEY_LOCAL_MACHINE\System\CurrentControlSet\Control\TimeZoneInformation" /v RealTimeIsUniversal /d 1 /t REG_DWORD /f
  # false zaten varsayılan; satır, nedeni görünsün diye açıkça yazıldı.
  # Kontrol: timedatectl → "RTC in local TZ: no"
  time.hardwareClockInLocalTime = false;

  # Dil: programların dili İngilizce (LANG), tarih, para, ölçü, kâğıt gibi biçimler Türkçe (LC_*).
  # /etc/locale.conf'a yazılır, oturum açılırken okunur: değişince oturumu kapatıp aç.   Kontrol: locale
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

  # Klavye düzeni. Adında "xserver" geçse de yalnızca X için değil: /etc/X11/xorg.conf.d/00-keyboard.conf'a
  # yazılır, giriş ekranını çizen KWin oradan okur. Hyprland'in içindeki düzenler ayrı:
  # desk Ayarlar → Klavye ve fare (desk-ayarlar.json; ilk değer hypr/config/input.lua).
  services.xserver.xkb.layout = "tr";
  # Metin konsolunun (Ctrl+Alt+F2… ile geçilen TTY) düzeni. Açılışta systemd-vconsole-setup uygular.
  console.keyMap = "trq";

  # ---------------------------------------------------------------
  # desk (sistem tarafı)
  # ---------------------------------------------------------------
  # desk/nix/nixos.nix'i açar. Getirdikleri (burada ayrıca yazmaya gerek yok):
  #   - kilit ekranlarının şifre denetimi (PAM: desk-lock, yedek olarak hyprlock)
  #   - upower (pil bilgisi) ve power-profiles-daemon (güç modu: Dengeli / Performans / Tasarruf)
  #   - Inter ve JetBrains Mono yazı tipleri
  #   - ekran kaydı izni (gpu-screen-recorder) ve pil koruma dosyalarına yazma izni (udev kuralı)
  #   - giriş ekranı: desk teması, onu çizen KWin, Bibata imleci, ilk açılışta seçili oturum
  # Kullanıcı tarafı (desk'in programları, desk ve hypridle servisleri) ayrı: home.nix → desk.enable.
  desk.enable = true;

  # ---------------------------------------------------------------
  # Ağ, Bluetooth, disk bağlama
  # ---------------------------------------------------------------
  # Bilgisayarın ağdaki adı. flake.nix'teki "legion5" ile aynı: nixos-rebuild'e "#ad" verilmezse
  # bu adı arar.
  networking.hostName = "legion5";
  # NetworkManager: Wi-Fi ve kablolu bağlantıları yönetir. desk'in Wi-Fi sayfası onunla nmcli
  # üzerinden konuşur.   Kontrol: nmcli device
  networking.networkmanager.enable = true;

  # Bluetooth (BlueZ servisi). powerOnBoot: açılışta açık gelir; desk'in kontrol merkezinden kapatılır.
  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
  };

  # udisks2: USB bellek gibi diskleri root şifresi sormadan bağlar. Dolphin'in kenar çubuğu bunu kullanır.
  services.udisks2.enable = true;

  # ---------------------------------------------------------------
  # Ses
  # ---------------------------------------------------------------
  # PipeWire: bütün sesin (ve ekran paylaşımında görüntünün) geçtiği sunucu. Sistem servisi değil,
  # kullanıcı servisi: oturum açılınca başlar.   Kontrol: wpctl status
  #   alsa:        doğrudan ALSA kullanan programlar da PipeWire'dan geçsin
  #   alsa.support32Bit: 32 bitlik programlar için de (Wine, Steam)
  #   pulse:       PulseAudio bekleyen programlar çalışsın (pavucontrol, Spotify, tarayıcılar)
  #   wireplumber: hangi sesin hangi çıkışa gideceğine karar veren yönetici (varsayılan aygıt dahil)
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    wireplumber.enable = true;
  };
  # rtkit: PipeWire'ın gerçek zamanlı öncelik alabilmesi; işlemci yükteyken ses cızırdamasın.
  security.rtkit.enable = true;

  # ---------------------------------------------------------------
  # Grafik: AMD (ekran) + Nvidia RTX 2060 (gerektiğinde)
  # ---------------------------------------------------------------
  # Düzen: ekranı her zaman AMD (işlemcinin içindeki ekran kartı) çizer. Nvidia yalnızca bir program
  # özellikle isterse çalışır (nvidia-offload / prime-run), geri kalan zamanda kapanıp pil harcamaz.
  # Hyprland'in yalnızca AMD'yi kullanması home.nix'teki ~/.config/uwsm/env-hyprland'de.

  # OpenGL/Vulkan sürücüleri (Mesa: AMD). enable32Bit: 32 bitlik oyunlar ve Wine için.
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };

  # Adında "xserver" geçse de Wayland için de gerekli: Nvidia'nın çekirdek modülünü ve sürücüsünü
  # kurar. AMD'nin sürücüsü (amdgpu) çekirdeğin içinde, kendiliğinden yüklenir.
  services.xserver.videoDrivers = [ "nvidia" ];

  hardware.nvidia = {
    # nvidia-drm.modeset=1: Wayland'in Nvidia'yla çalışması için şart.
    modesetting.enable = true;
    # Uyku öncesi Nvidia'nın belleğini kaydeden servisler kapalı: ekranı AMD çizdiği için gerekmedi.
    powerManagement.enable = false; # Uykudan uyanmada sorun çıkarsa ilk denenecek: true

    # Boştayken Nvidia'yı kapatma. İnce ayarlı mod (finegrained, 0x02) bu bilgisayarda (Legion 5,
    # Ryzen 4000) desteklenmiyor; kaba mod (0x01) kullanılıyor: Nvidia'yı kullanan hiçbir program
    # kalmayınca kart tamamen kapanır. Bunun için çekirdeğin güç yönetimine izin vermesi gerekiyor:
    # aşağıdaki udev kuralları. (finegrained = true olsaydı NixOS o kuralları kendisi eklerdi.)
    # Kontrol: cat /sys/bus/pci/devices/0000:01:00.0/power/runtime_status → boştayken "suspended"
    powerManagement.finegrained = false;
    moduleParams.nvidia.NVreg_DynamicPowerManagement = "0x01";
    # Nvidia'nın kapalı kaynak çekirdek modülü. RTX 20 (Turing) açık modülle de çalışır; sorunsuz
    # çalıştığı için değiştirilmedi.
    open = false;
    # nvidia-settings penceresi (sürücü bilgisi, sıcaklık).
    nvidiaSettings = true;
    # Sürücünün "production" (kararlı) dalı. config.boot.kernelPackages'tan alındığı için çekirdek
    # değişince sürücü o çekirdeğe göre derlenir.
    package = config.boot.kernelPackages.nvidiaPackages.production;

    # PRIME offload: AMD ekranı çizer, Nvidia istenince hesaplar, sonuç AMD üzerinden gösterilir.
    prime = {
      offload = {
        enable = true;
        enableOffloadCmd = true; # "nvidia-offload <program>" komutu (home.nix'teki prime-run onu kullanır)
      };
      # Kartların PCI adresleri: "lspci | grep -E 'VGA|3D'" → 05:00.0 (AMD), 01:00.0 (Nvidia)
      amdgpuBusId = "PCI:5:0:0";
      nvidiaBusId = "PCI:1:0:0";
    };
  };

  # Ekran kartlarına sabit adlar: card0/card1 sırası açılışta yer değiştirebiliyor, bu adlar değişmez.
  #   /dev/dri/amd-igpu, /dev/dri/nvidia-dgpu → home.nix'teki AQ_DRM_DEVICES bunları kullanır.
  # Son iki kural Nvidia'nın güç yönetimi için (yukarıdaki kaba mod): sürücü karta bağlanınca
  # (bind) otomatik güç yönetimine izin ver, ayrılınca (unbind) kapat.
  # Ne zaman: udev, aygıt her göründüğünde (açılışta) uygular.   Kontrol: ls -l /dev/dri
  services.udev.extraRules = ''
    KERNEL=="card*", KERNELS=="0000:05:00.0", SUBSYSTEM=="drm", SUBSYSTEMS=="pci", SYMLINK+="dri/amd-igpu"
    KERNEL=="card*", KERNELS=="0000:01:00.0", SUBSYSTEM=="drm", SUBSYSTEMS=="pci", SYMLINK+="dri/nvidia-dgpu"

    # Nvidia sürücüye bağlanınca güç yönetimine izin ver (kaba mod için gerekli)
    ACTION=="bind", SUBSYSTEM=="pci", ATTR{vendor}=="0x10de", ATTR{class}=="0x030000", TEST=="power/control", ATTR{power/control}="auto"
    ACTION=="unbind", SUBSYSTEM=="pci", ATTR{vendor}=="0x10de", ATTR{class}=="0x030000", TEST=="power/control", ATTR{power/control}="on"
  '';

  # ---------------------------------------------------------------
  # Giriş ekranı ve masaüstü: SDDM + Hyprland (uwsm ile)
  # ---------------------------------------------------------------
  # Oturum açılış zinciri:
  #   SDDM (giriş ekranı; desk teması, KWin çizer) → şifre doğru → "Hyprland (uwsm-managed)" oturumu
  #   → uwsm ~/.config/uwsm/env-hyprland'i okur (hangi ekran kartı; home.nix) ve Hyprland'i bir
  #     systemd kullanıcı servisi olarak başlatır
  #   → Hyprland ~/.config/hypr/hyprland.lua'yı okur (kısayollar, görünüm, autostart.lua)
  #   → Hyprland hazır olunca graphical-session.target açılır, ona bağlı kullanıcı servisleri başlar:
  #     desk, hypridle, cliphist (desk/nix/home.nix), EasyEffects, polkit penceresi (home.nix)
  #   Çıkışta (logout) hepsi birlikte kapanır.
  # Kontrol: systemctl --user list-units --type=service --state=running
  services.displayManager.sddm = {
    enable = true;
    # Giriş ekranı Wayland'de çizilsin (X sunucusu hiç açılmaz). Çizen program desk'ten: KWin.
    wayland.enable = true;
  };

  programs.hyprland = {
    # Hyprland'i, giriş ekranındaki oturum kaydını ve xdg-desktop-portal-hyprland'i (ekran
    # paylaşımı, ekran görüntüsü isteyen programlar için) kurar.
    enable = true;
    # X11 programları (eski oyunlar, bazı Java/Wine programları) Hyprland'de XWayland ile açılır.
    xwayland.enable = true;
    # uwsm: Hyprland'i systemd'ye bağlar; servisler oturumla başlar, oturumla kapanır.
    # Giriş ekranındaki "Hyprland (uwsm-managed)" seçeneği budur.
    withUWSM = true;
  };

  # Portallar: programların "dosya seç", "ekranı paylaş" gibi isteklerini karşılayan aracı servisler.
  # Hyprland'inki (ekran paylaşımı) yukarıdan geliyor; GTK'nınki dosya seçme pencereleri için
  # (Zen, Electron uygulamaları).
  xdg.portal.extraPortals = [ pkgs.xdg-desktop-portal-gtk ];

  # Her oturumda tanımlı ortam değişkenleri (/etc/pam/environment ve /etc/profile'a yazılır).
  # Oturum açılırken okunur: değiştirince oturumu kapatıp aç.   Kontrol: echo $NIXOS_OZONE_WL
  environment.sessionVariables = {
    # Electron uygulamaları (VS Code, Obsidian, Spotify) Wayland'de açılsın: nixpkgs'in bu
    # programlar için yazdığı başlatıcılar bu değişkene bakar.
    NIXOS_OZONE_WL = "1";
    # Qt programları görünümünü qt6ct'den alsın (~/.config/qt6ct/qt6ct.conf; qt6ct penceresiyle
    # değişir). Dolphin'in koyu temada siyah yazı sorununu çözen ayar (CachyOS'taki çözüm).
    QT_QPA_PLATFORMTHEME = "qt6ct";
  };

  # dconf: GTK/GNOME programlarının ayar veritabanı. home.nix'teki dconf.settings (koyu tema
  # tercihi) ve programların kendi ayarlarını kaydetmesi bunu ister.
  programs.dconf.enable = true;

  # NixOS'ta hazır derlenmiş (Nix için yapılmamış) programlar çalışmaz: beklediği yükleyiciyi
  # (/lib64/ld-linux…) bulamaz. nix-ld o yolda bir yükleyici sağlar. Gerekenler: uv ile kurulan
  # Python paketlerinin içindeki derlenmiş parçalar, VS Code eklentilerinin indirdiği programlar.
  programs.nix-ld.enable = true;

  # Oyunlar Windows'ta. Steam gerekirse aç; 40 GB'a dikkat (plan: Sorun 43).
  # programs.steam.enable = true;

  # ---------------------------------------------------------------
  # Yazı tipleri
  # ---------------------------------------------------------------
  # Kurulu yazı tipleri; programlar onları fontconfig üzerinden bulur. desk Inter ve JetBrains Mono'yu
  # kendisi ekliyor (desk/nix/nixos.nix).   Kontrol: fc-list | grep -i inter
  fonts.packages = with pkgs; [
    nerd-fonts.jetbrains-mono # simgeli JetBrains Mono: terminaldeki simgeler (starship, eza, yazi)
    noto-fonts # neredeyse bütün dillerin harfleri
    noto-fonts-color-emoji # renkli emojiler
  ];

  # Bir program yalnızca tür isterse ("sans-serif", "monospace") hangi yazı tipi verilsin.
  # Listedeki ilk yazı tipinde olmayan bir harf, sıradakinden alınır.   Kontrol: fc-match sans-serif
  fonts.fontconfig.defaultFonts = {
    sansSerif = [ "Inter" "Noto Sans" ];
    monospace = [ "JetBrains Mono" ];
    emoji = [ "Noto Color Emoji" ];
  };

  # ---------------------------------------------------------------
  # Kullanıcı
  # ---------------------------------------------------------------
  # fish sistem düzeyinde de açık olmalı: giriş kabuğu olabilmesi için /etc/shells'e eklenir ve
  # sistem programlarının fish tamamlamaları yüklenir. Kullanıcı ayarları (takma adlar, starship) home.nix'te.
  programs.fish.enable = true;

  users.users.mustafa = {
    isNormalUser = true; # ev klasörü (/home/mustafa), "users" grubu, 1000 ve üstü kullanıcı numarası
    description = "Mustafa"; # tam ad (giriş ekranında görünen)
    shell = pkgs.fish;
    # Gruplar (değişince oturumu kapatıp aç; kontrol: groups):
    #   wheel:          sudo kullanabilir
    #   networkmanager: Wi-Fi bağlantılarını yönetici şifresi sormadan değiştirebilir
    #   video:          görüntü aygıtları ve parlaklık için klasik grup (bugün çoğu erişimi oturum
    #                   yöneticisi logind veriyor; zararsız olduğu için duruyor)
    # "input" grubu bilerek yok: o gruptaki her program /dev/input'tan bütün tuş vuruşlarını (şifreler
    # dahil) okuyabilir. Hyprland klavyeye ve fareye logind üzerinden erişiyor, gruba ihtiyacı yok.
    extraGroups = [ "wheel" "networkmanager" "video" ];
  };
  # Şifre burada değil: passwd komutuyla verilir, /etc/shadow'da durur; updatenix ona dokunmaz.

  # Bütün kullanıcıların (root dahil) PATH'inde olan temel araçlar. Kişisel programlar home.nix'te.
  environment.systemPackages = with pkgs; [
    git # sürüm kontrolü; ~/nixos-config bir git deposu
    curl
    wget
    pciutils # lspci (ekran kartlarının adresleri)
    usbutils # lsusb
    btrfs-progs # btrfs komutu (alt birimler, sıkıştırma oranı, tarama)
  ];

  # ---------------------------------------------------------------
  # Nix ve disk (40 GB kuralları — plan: Bölüm 2)
  # ---------------------------------------------------------------
  # Kapalı kaynak paketlere izin (Nvidia sürücüsü, VS Code, Spotify, Obsidian). Home Manager da aynı
  # nixpkgs'i kullandığı için (flake.nix → useGlobalPkgs) home.nix'teki paketler için de geçerli.
  nixpkgs.config.allowUnfree = true;

  # /etc/nix/nix.conf'a yazılır; nix komutları ve nix-daemon okur.
  nix.settings = {
    # flake'ler ve yeni "nix" komutu (nix flake update, nix eval…) hâlâ "deneysel" sayılıyor.
    experimental-features = [ "nix-command" "flakes" ];
    # Nix indirme hızı ayarları: aynı anda açılacak bağlantı, aynı anda indirilecek paket,
    # indirme arabelleği (512 MB).
    http-connections = 50;
    max-substitution-jobs = 32;
    download-buffer-size = 512 * 1024 * 1024;

    # Boş yer 3 GB'ın altına inerse, derleme sırasında 8 GB boşalana kadar temizlik yap
    min-free = 3 * 1024 * 1024 * 1024;
    max-free = 8 * 1024 * 1024 * 1024;
  };

  # Aynı dosyaları birleştirme: /nix/store'da içeriği aynı olan dosyalar tek kopyaya bağlanır (yer
  # kazandırır). Her gün 03:45'te; bilgisayar o saatte kapalıysa bir sonraki açılışta.
  # Kontrol: systemctl status nix-optimise.timer
  nix.optimise.automatic = true;

  # Eski sürümleri silme: haftada bir, 7 günden eski sistem sürümleri silinir, sonra hiçbir sürümün
  # kullanmadığı paketler /nix/store'dan atılır. Elle: nixclean (home.nix).   Kontrol: systemctl status nix-gc.timer
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 7d";
  };

  # Günlüklerin (journalctl) diskte kaplayabileceği en çok yer.   Kontrol: journalctl --disk-usage
  services.journald.settings.Journal.SystemMaxUse = "200M";

  # Kurulumdaki NixOS sürümü. Sistemin sürümü değil (o flake.lock'tan gelir); bazı servislerin
  # veri biçimleri buna göre seçilir. Değiştirilmez.
  system.stateVersion = "26.05";
}
