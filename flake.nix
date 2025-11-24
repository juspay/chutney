{
  nixConfig = {
    extra-substituters = "https://cache.nixos-asia.org/oss";
    extra-trusted-public-keys = "oss:KO872wNJkCDgmGN3xy9dT89WAhvv13EiKncTtHDItVU=";
  };
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";
    systems.url = "github:nix-systems/default";
    flake-parts.url = "github:hercules-ci/flake-parts";
    terranix = {
      url = "github:terranix/terranix/pull/133/head";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.flake-parts.follows = "flake-parts";
      inputs.systems.follows = "systems";
    };
    agenix = {
      url = "github:ryantm/agenix";
      inputs.nixpkgs.follows = "nixpkgs";
      # Ignore dependencies not relevant for using the nixosModule
      inputs.darwin.follows = "";
      inputs.home-manager.follows = "";
    };
    attic = {
      url = "github:shivaraj-bh/attic/max-nar-info-size"; # https://github.com/zhaofengli/attic/pull/252
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.nixpkgs-stable.follows = "nixpkgs";
      inputs.flake-parts.follows = "flake-parts";
    };
  };
  outputs = inputs: inputs.flake-parts.lib.mkFlake { inherit inputs; } {
    systems = import inputs.systems;
    imports = with builtins; map (fn: ./modules/flake-parts/${fn}) (attrNames (readDir ./modules/flake-parts));
    flake = {
      nixosModules = {
        attic = ./modules/nixos/attic.nix;
        minio-attic = ./modules/nixos/minio-attic.nix;
      };
      overlays.default = final: prev:
        let
          inherit (final.stdenv.hostPlatform) system;
        in
        {
          attic-server = inputs.attic.packages.${system}.attic-server;
        };
    };
  };
}
