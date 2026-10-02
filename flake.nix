{
	description = "legion5 Flake";

	inputs = {
		nixpkgs.url = "nixpkgs/nixos-unstable";
		home-manager = {
			url = "github:nix-community/home-manager";
			inputs.nixpkgs.follows = "nixpkgs";
		};
		serpantinum.url = "github:ilyamiro/serpantinum";
		zen-browser = {
      			url = "github:youwen5/zen-browser-flake";
      			inputs.nixpkgs.follows = "nixpkgs";
    		};
	};

	outputs = { self, nixpkgs, home-manager, serpantinum, ... }@inputs: {
		nixosConfigurations.legion5 = nixpkgs.lib.nixosSystem {
			system = "x86_64-linux";
			specialArgs = { inherit serpantinum inputs; };
			modules = [
				./configuration.nix
				serpantinum.nixosModules.default
				home-manager.nixosModules.home-manager 
				{
					home-manager = 
					{
						useGlobalPkgs = true;
						useUserPackages = true;
						extraSpecialArgs = { inherit serpantinum inputs; };
						users.mustafa = import ./home.nix;
						backupFileExtension = "backup";
					};
				}
			];
		};
	};
}
