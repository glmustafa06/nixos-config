{ config, pkgs, serpantinum, ... }: {
	imports = [ serpantinum.homeManagerModules.default ];

	home.username = "mustafa";
	home.homeDirectory = "/home/mustafa";
	home.stateVersion = "26.05";
	
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

	xdg.configFile."hypr".source = config.lib.file.mkOutOfStoreSymlink "/etc/nixos/hypr";



	programs.bash = {
		enable = true;
		shellAliases = {
			btw = "echo i use nixos-hyprland btw";
			updatenix = "sudo nixos-rebuild switch --flake /etc/nixos#legion5";
			cdnix = "cd /etc/nixos/";	
		};
		#profileExtra = ''
		#	if [ -z "$WAYLAND_DISPLAY" ] && [ "$XDG_VTNR" = 1 ]; then
		#	exec uwsm start -S hyprland-uwsm.desktop
		#	fi
		#'';
	};
	
}
