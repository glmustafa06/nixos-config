{
	description = "legion5 Flake";

	inputs = {
		nixpkgs.url = "nixpkgs/nixos-unstable";
		home-manager = {
			url = "github:nix-community/home-manager";
			inputs.nixpkgs.follows = "nixpkgs";
		};
		serpantinum.url = "github:ilyamiro/serpantinum";
	};

	outputs = { nixpkgs, home-manager, serpantinum, ... }: {
		nixosConfigurations.legion5 = nixpkgs.lib.nixosSystem {
			system = "x86_64-linux";
			specialArgs = { inherit serpantinum; };
			modules = [
				./configuration.nix
				serpantinum.nixosModules.default
				home-manager.nixosModules.home-manager 
				{
					home-manager = 
					{
						useGlobalPkgs = true;
						useUserPackages = true;
						extraSpecialArgs = { inherit serpantinum; };
						users.mustafa = import ./home.nix;
						backupFileExtension = "backup";
					};
				}
			];
		};
	};
}
