{ inputs, pkgs, ... }:
let
  inherit (pkgs.stdenv.hostPlatform) system;
in
{
  nixpkgs = {
    config.allowUnfree = true;
    overlays = [
      (final: prev: {
        attic-server = inputs.attic.packages.${system}.attic-server;
      })
    ];
  };
}
