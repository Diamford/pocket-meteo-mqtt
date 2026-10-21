{
  description = "NixOS configuration with Plasma 6";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";

    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    
  };

  outputs = { self, nixpkgs, disko, ... }@inputs: {

    nixosConfigurations = {
      pocket-meteo-mqtt = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
	modules = [
	  ./disko-configs/disko.nix
	  ./configuration.nix
	  ./hardware.nix
	  disko.nixosModules.disko
	];
      };
    };
  };
}
