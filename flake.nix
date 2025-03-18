{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11";
    flake-parts.url = "github:hercules-ci/flake-parts";
  };
  outputs = inputs: inputs.flake-parts.lib.mkFlake { inherit inputs; } {
    flake.nixosConfigurations.chutney = inputs.nixpkgs.lib.nixosSystem {
      system = "aarch64-linux";
      modules = [
        "${inputs.nixpkgs}/nixos/maintainers/scripts/ec2/amazon-image.nix"
        ./configuration.nix
        ./modules/nixos
      ];
    };
    systems = [ "x86_64-linux" "aarch64-linux" ];
    perSystem = { pkgs, ... }: {
      checks.integration = pkgs.testers.runNixOSTest ./tests/integration.nix;
    };
  };
}
