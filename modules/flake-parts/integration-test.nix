{ inputs, ... }:
{
  perSystem = { pkgs, lib, ... }: {
    # VM fails to boot successfully on `aarch64-linux`
    checks = lib.mkIf (pkgs.stdenv.isLinux && !pkgs.stdenv.isAarch64) {
      integration = pkgs.testers.runNixOSTest (import ../../tests/integration.nix inputs);
    };
  };
}
