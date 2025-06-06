{ inputs, pkgs, ... }:
let
  inherit (pkgs.stdenv.hostPlatform) system;
in
{
  nixpkgs = {
    # Also change <PerSystem>._module.args.pkgs.overlays if it doesn't import this module
    overlays = [
      (final: prev: {
        attic-server = inputs.attic.packages.${system}.attic-server;
      })
    ];
  };
}
