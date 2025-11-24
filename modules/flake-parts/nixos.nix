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
    specialArgs = {
      inherit inputs terranix-cfg;
      domain-name = "cache.nixos-asia.org";
    };
    modules = [
      "${inputs.nixpkgs}/nixos/maintainers/scripts/ec2/amazon-image.nix"
      ../../configuration.nix
      inputs.agenix.nixosModules.default
      inputs.self.nixosModules.attic

      # Overlays
      ({
        nixpkgs.overlays = [ inputs.self.overlays.default ];
      })

      # Autowire from terranix config
      ({ terranix-cfg, ... }: {
        services.atticd.settings.storage = {
          bucket = terranix-cfg.resource.aws_s3_bucket.chutney_attic_cache.bucket;
          region = terranix-cfg.provider.aws.region;
          type = "s3";
        };
      })

      # Configure secrets
      ({ config, ... }: {
        age.secrets = {
          "attic/env.age" = {
            owner = config.services.atticd.user;
            file = ../../secrets/attic/env.age;
          };
        };
        services.atticd.environmentFile = config.age.secrets."attic/env.age".path;
      })
    ];
  };
}
