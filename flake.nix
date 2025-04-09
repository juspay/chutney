{
  nixConfig = {
    extra-substituters = "http://65.0.102.202/oss";
    extra-trusted-public-keys = "oss:w/g6Ylufxm7hqOztR1wIw+Ig73zSCYMtpMi83UwlPlA=";
  };
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11";
    systems.url = "github:nix-systems/default";
    flake-parts.url = "github:hercules-ci/flake-parts";
    terranix = {
      url = "github:terranix/terranix";
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
  };
  outputs = inputs: inputs.flake-parts.lib.mkFlake { inherit inputs; } {
    flake.nixosConfigurations.chutney = inputs.nixpkgs.lib.nixosSystem {
      system = "aarch64-linux";
      modules = [
        "${inputs.nixpkgs}/nixos/maintainers/scripts/ec2/amazon-image.nix"
        ./configuration.nix
        inputs.agenix.nixosModules.default
        ./modules/nixos
      ];
    };
    systems = import inputs.systems;
    perSystem = { inputs', pkgs, system, ... }: {
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
      apps.vpc-sg-cleanup = {
        type = "app";
        program = pkgs.writeShellApplication {
          name = "vpc-sg-cleanup";
          runtimeInputs = [ pkgs.awscli2 ];
          text = ''
            SG_IDS=$(aws ec2 describe-security-groups \
              --filters "Name=vpc-id,Values=$1" \
              --region ap-south-1 \
              --query "SecurityGroups[?GroupName!='default'].GroupId" \
              --output text)
            for SG_ID in $SG_IDS; do
              echo "Deleting security group: $SG_ID"
              aws ec2 delete-security-group --group-id "$SG_ID" --region "ap-south-1"
            done
          '';
          meta.description = ''
            Manually delete the non-default security-group from a given VPC.

            `terraform destroy` only deletes the SG's managed by it. There can be other non-default SG's without
            deleting which the VPC will not be destroyed.
          '';
        };
      };
      devShells.default = pkgs.mkShell {
        packages = with pkgs; [
          just
          (terraform.withPlugins (p: [
            p.aws
          ]))
          inputs'.agenix.packages.default
          fd
          fzf
        ];
      };
      checks.integration = pkgs.testers.runNixOSTest (import ./tests/integration.nix inputs);
    };
  };
}
