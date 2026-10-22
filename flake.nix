{
  description = "PocketMeteo MQTT Docker image";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";

  outputs = { self, nixpkgs }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs { inherit system; };
    in {
      packages.${system}.default =
        import ./docker/mqtt-image.nix {
          inherit pkgs;
          lib = pkgs.lib;
          inherit nixpkgs system;
        };
    };
}
