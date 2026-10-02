{ config, pkgs, inputs, ... }:

{
  	home.username = "mustafa";
 	home.homeDirectory = "/home/mustafa";
  	home.stateVersion = "26.05";

  	# Serpantinum Shell Entegrasyonu
  	imports = [ inputs.serpantinum.homeManagerModules.default ];

  	# Kullanıcı Paketleri
  	home.packages = with pkgs; [
    		# Tarayıcı (Flake'den gelen Zen Browser)
    		inputs.zen-browser.packages."${pkgs.stdenv.hostPlatform.system}".default
   		
		#Ofis
		onlyoffice-desktopeditors

    		# Terminal & Geliştirme
    		kitty
    		ghostty
    		neovim
    		git
    		wget
    		fastfetch
    		bat
    		eza
		yazi
		tree

    		# Arayüz & Görsel Araçlar
    		waybar
    		hyprpaper
    		kdePackages.dolphin
    		bibata-cursors
  	];

  	# İmleç Ayarları (Sistem genelinde ve pencerelerde aktifleşmesi için)
  	home.pointerCursor = {
    		enable = true;
    		package = pkgs.bibata-cursors;
    		name = "Bibata-Modern-Classic";
    		size = 24;
    		gtk.enable = true;
  		x11.enable = true;
		x11.defaultCursor = "Bibata-Modern-Dark";
	};

  	# Serpantinum Shell Konfigürasyonu
  	programs.serpantinum = {
    		enable = true;
    		systemd.enable = true;
    		settings = {
      			wallpaperDir = "/home/mustafa/Pictures/Wallpapers";
      			general = {
        			language = "en";
        			weatherUnit = "metric";
      			};
    		};
  	};

 	# Hyprland Config Sembolik Bağı (Symlink)
  	xdg.configFile."hypr".source = config.lib.file.mkOutOfStoreSymlink "/etc/nixos/hypr";

  	# Bash ve Alias Tanımları
  	programs.bash = {
    		enable = true;
    		shellAliases = {
      			btw = "echo i use nixos-hyprland btw";
      			updatenix = "sudo nixos-rebuild switch --flake /etc/nixos#legion5";
      			cdnix = "cd /etc/nixos/";    
    		};
  	};
}
