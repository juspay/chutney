{ inputs, ... }:
{
  flake.nixosConfigurations.chutney = inputs.nixpkgs.lib.nixosSystem {
    system = "aarch64-linux";
    specialArgs = { inherit inputs; };
    modules = [
      "${inputs.nixpkgs}/nixos/maintainers/scripts/ec2/amazon-image.nix"
      ./configuration.nix
      inputs.agenix.nixosModules.default
      ./modules/nixos
    ];
  };
}
