{ config, pkgs, inputs, ... }:

{
  	imports =
    		[
      		./hardware-configuration.nix
    		];

  	# Use the systemd-boot EFI boot loader.
  	boot.loader.systemd-boot.enable = true;
  	boot.loader.efi.canTouchEfiVariables = true;

  	# Use latest kernel.
  	boot.kernelPackages = pkgs.linuxPackages_latest;

  	networking.hostName = "legion5"; # Define your hostname.

  	# Enable networking
  	networking.networkmanager.enable = true;
  
  	# Ses
	services.pipewire = {
  		enable = true;

  			alsa = {
				enable = true;
    				support32Bit = true;
  			};

  			pulse.enable = true;

  			wireplumber.enable = true;
		};

 	 # Grafik Hızlandırma Desteği
  	hardware.graphics = {
    		enable = true;
    		enable32Bit = true;
  	};

  	# NVIDIA Sürücüsünü Yükle
  	services.xserver.videoDrivers = [ "nvidia" ];

  	hardware.nvidia = {
    		modesetting.enable = true;
    		powerManagement.enable = false;
    		
		# Bu ayar CUDA işlemleri yokken kartı uyutur
    		powerManagement.finegrained = true;
    		open = false;
    		nvidiaSettings = true;
    		package = config.boot.kernelPackages.nvidiaPackages.production;
  	};

  	# Hybrid (Offload) Yapılandırması
  	hardware.nvidia.prime = {
    		offload = {
      			enable = true;
      			enableOffloadCmd = true; # nvidia-offload komutunu sisteme ekler
 	   		};
  
    		amdgpuBusId = "PCI:5:0:0"; 
    		nvidiaBusId = "PCI:1:0:0"; 
  		};

  	# Set your time zone.
  	time.timeZone = "Europe/Istanbul";

	services.displayManager.sddm.enable = true;
	services.displayManager.sddm.wayland.enable = true;
	environment.sessionVariables.WLR_NO_HARDWARE_CURSORS = "1";
	environment.sessionVariables.NIXOS_OZONE_WL = "1";
	programs.dconf.enable = true;

  	programs.hyprland = {
		enable = true;
		xwayland.enable = true;
		withUWSM = true;
  	};

  	programs.serpantinum.enable = true;

  	# Select internationalisation properties.
  	i18n.defaultLocale = "en_US.UTF-8";

  	i18n.extraLocaleSettings = {
    		LC_ADDRESS = "tr_TR.UTF-8";
    		LC_IDENTIFICATION = "tr_TR.UTF-8";
    		LC_MEASUREMENT = "tr_TR.UTF-8";
    		LC_MONETARY = "tr_TR.UTF-8";
    		LC_NAME = "tr_TR.UTF-8";
    		LC_NUMERIC = "tr_TR.UTF-8";
    		LC_PAPER = "tr_TR.UTF-8";
    		LC_TELEPHONE = "tr_TR.UTF-8";
    		LC_TIME = "tr_TR.UTF-8";
  	};

  	# Configure keymap in X11
  	services.xserver.xkb = {
    		layout = "tr";
    		variant = "";
  	};

  	console.keyMap = "trq";

  	users.users."mustafa" = {
    		isNormalUser = true;
    		description = "mustafa";
    		extraGroups = [ "networkmanager" "wheel" ];	
		packages = with pkgs; [];
  	};

	environment.systemPackages = with pkgs; [
  		pulseaudio
		easyeffects
	];
	
  	# Allow unfree packages
  	nixpkgs.config.allowUnfree = true;

 	services.upower.enable = true;

 	nix.settings.experimental-features = [ "nix-command" "flakes"];

 	system.stateVersion = "26.05";

}
