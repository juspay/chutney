{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11";
  };
  outputs = inputs: {
    nixosConfigurations.chutney = inputs.nixpkgs.lib.nixosSystem {
      system = "aarch64-linux";
      modules = [
        "${inputs.nixpkgs}/nixos/maintainers/scripts/ec2/amazon-image.nix"
        ./configuration.nix
        ./modules/nixos
      ];
    };
  };
}
