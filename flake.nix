{
  description = "legion5 — NixOS + Hyprland + Desk";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    zen-browser = {
      url = "github:youwen5/zen-browser-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { nixpkgs, home-manager, ... }@inputs: {
    nixosConfigurations.legion5 = nixpkgs.lib.nixosSystem {
      # Mimari hardware-configuration.nix'teki nixpkgs.hostPlatform'dan gelir.
      specialArgs = { inherit inputs; };
      modules = [
        ./configuration.nix
        ./desk/nix/nixos.nix # desk'in sistem tarafı (configuration.nix → desk.enable)
        home-manager.nixosModules.home-manager
        {
          home-manager = {
            useGlobalPkgs = true;
            useUserPackages = true;
            extraSpecialArgs = { inherit inputs; };
            users.mustafa = import ./home.nix;
            # Home Manager var olan bir dosyanın üstüne yazacaksa eskisini .backup uzantısıyla saklar
            backupFileExtension = "backup";
          };
        }
      ];
    };
  };
}
