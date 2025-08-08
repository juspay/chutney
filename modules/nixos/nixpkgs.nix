{ inputs, pkgs, ... }:
let
  inherit (pkgs.stdenv.hostPlatform) system;
in
{
  nixpkgs = {
    overlays = [
      (final: prev: {
        attic-server = inputs.attic.packages.${system}.attic-server;
      })
    ];
  };
}
