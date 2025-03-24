{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11";
    systems.url = "github:nix-systems/default";
    flake-parts.url = "github:hercules-ci/flake-parts";
    terranix = {
      url = "github:terranix/terranix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
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
    perSystem = { pkgs, system, ... }: {
      _module.args.pkgs = import inputs.nixpkgs {
        inherit system;
        # terraform has an unfree license
        config.allowUnfree = true;
      };
      packages.default = inputs.terranix.lib.terranixConfiguration {
        inherit system;
        extraArgs = {
          flake = { inherit inputs; };
        };
        modules = [ ./modules/terranix ];
      };
      devShells.default = pkgs.mkShell {
        packages = with pkgs; [
          just
          (terraform.withPlugins (p: [
            p.aws
          ]))
        ];
      };
      checks.integration = pkgs.testers.runNixOSTest ./tests/integration.nix;
    };
  };
}
