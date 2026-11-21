# ═══════════════════════════════════════════════════════════════════════════
# flake.nix — her şeyin giriş kapısı
# ═══════════════════════════════════════════════════════════════════════════
#
# Harita (kim kimi okur):
#
#   flake.nix
#   ├─ inputs: paketlerin ve modüllerin nereden geldiği (hangi sürüm olduğu flake.lock'ta kilitli)
#   └─ nixosConfigurations.legion5: bu bilgisayarın sistemi = aşağıdaki modüllerin birleşimi
#        ├─ configuration.nix              sistem: önyükleme, diskler, ekran kartları, ses, kullanıcı…
#        │   └─ hardware-configuration.nix  kurulumda üretilen donanım kısmı (diskler, initrd)
#        ├─ desk/nix/nixos.nix             desk'in sistem tarafı (kilidin şifre denetimi, pil, giriş ekranı…)
#        └─ Home Manager → home.nix        kullanıcı: programlar, ~/.config dosyaları, kullanıcı servisleri
#            └─ desk/nix/home.nix          desk'in kullanıcı tarafı (desk ve hypridle servisleri…)
#
#   Nix'e kopyalanmayan, bağlantıyla (symlink) kullanılan klasörler. Düzenleyince hemen geçerli
#   olur, updatenix gerekmez:
#     ~/nixos-config/hypr  ← ~/.config/hypr            Hyprland: kısayollar, görünüm (home.nix)
#     ~/nixos-config/desk  ← ~/.config/quickshell/desk  desk'in arayüzü: QML, betikler (desk/nix/home.nix)
#     ~/nixos-config/desk-ayarlar.json                  desk'in Ayarlar penceresinin kaydettikleri
#
# Komutlar (takma adlar home.nix → programs.fish'te):
#   updatenix    sudo nixos-rebuild switch --flake ~/nixos-config#legion5
#                Bu dosyadan başlayıp her şeyi okur, eksikleri indirir ya da derler, yeni sürüme geçer.
#   flakeupdate  nix flake update --flake ~/nixos-config
#                flake.lock'u en yeni sürümlere çeker; kurulması için ardından updatenix.
#   nixsize      Yeni sürüme geçmeden neyin indirileceğini, neyin derleneceğini gösterir.
#
# Önemli: flake yalnızca git'in bildiği dosyaları görür. Yeni bir dosya eklendiyse updatenix'ten önce
#   git -C ~/nixos-config add -A
# (yoksa "path ... does not exist" gibi bir hata çıkar). Commit şart değil, add yeterli.
{
  description = "legion5 — NixOS + Hyprland + Desk";

  inputs = {
    # nixpkgs: bütün paketler ve NixOS'un modülleri. nixos-unstable dalı sürekli güncellenir, ama
    # yalnızca NixOS'un otomatik testlerini geçen sürümler bu dala gelir.
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    # Home Manager: kullanıcı tarafını (home.nix) Nix'le yönetmeyi sağlar.
    # follows: kendi ayrı nixpkgs'ini indirmesin, yukarıdakini kullansın (tek sürüm, daha az yer).
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Zen tarayıcı nixpkgs'te yok; bu flake'ten geliyor (home.nix → inputs.zen-browser…).
    zen-browser = {
      url = "github:youwen5/zen-browser-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  # outputs: bu flake'in ürettikleri; burada tek bir şey var, legion5 adlı NixOS sistemi.
  # "{ nixpkgs, home-manager, ... }@inputs": girişleri hem tek tek (nixpkgs, home-manager) hem de
  # hepsini birden (inputs) kullanılabilir yapar.
  outputs = { nixpkgs, home-manager, ... }@inputs: {
    nixosConfigurations.legion5 = nixpkgs.lib.nixosSystem {
      # Mimari hardware-configuration.nix'teki nixpkgs.hostPlatform'dan gelir.
      # specialArgs: NixOS modüllerine (configuration.nix…) ek argüman olarak "inputs" verir.
      specialArgs = { inherit inputs; };
      # Bu modüller tek bir ayar ağacında birleşir (nasıl birleştikleri: configuration.nix'in başı).
      modules = [
        ./configuration.nix
        ./desk/nix/nixos.nix # desk'in sistem tarafı (configuration.nix → desk.enable)
        # Home Manager'ı NixOS'un içine yerleştirir: ayrı bir "home-manager switch" komutu yok,
        # updatenix ikisini birlikte uygular. Kullanıcı tarafı home-manager-mustafa servisiyle
        # yazılır: her updatenix'te ve her açılışta.
        # Hata olursa: journalctl -u home-manager-mustafa
        home-manager.nixosModules.home-manager
        {
          home-manager = {
            # home.nix sistemle aynı nixpkgs'i ve onun ayarlarını (allowUnfree) kullanır.
            useGlobalPkgs = true;
            # home.packages /etc/profiles/per-user/mustafa'ya kurulur (~/.nix-profile yerine).
            useUserPackages = true;
            # home.nix'e de "inputs" ver (zen-browser için).
            extraSpecialArgs = { inherit inputs; };
            users.mustafa = import ./home.nix;
            # Home Manager var olan bir dosyanın üstüne yazacaksa eskisini .backup uzantısıyla saklar.
            # O .backup zaten varsa updatenix "would be clobbered" hatası verir: eski .backup'ı sil.
            backupFileExtension = "backup";
          };
        }
      ];
    };
  };
}
