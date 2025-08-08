{ inputs, ... }:
let
  system = "aarch64-linux";
  terranix-cfg = (inputs.terranix.lib.terranixConfigurationAst {
    inherit system;
    modules = [ ../../modules/terranix ];
  }).config;
in
{
  flake.nixosConfigurations.chutney = inputs.nixpkgs.lib.nixosSystem {
    inherit system;
    specialArgs = { inherit inputs terranix-cfg; };
    modules = [
      "${inputs.nixpkgs}/nixos/maintainers/scripts/ec2/amazon-image.nix"
      ../../configuration.nix
      inputs.agenix.nixosModules.default
      ../../modules/nixos
      ({terranix-cfg, ...}: {
        services.atticd.settings.storage = {
          bucket = terranix-cfg.resource.aws_s3_bucket.chutney_attic_cache.bucket;
          region = terranix-cfg.provider.aws.region;
          type = "s3";
        };
      })
    ];
  };
}
