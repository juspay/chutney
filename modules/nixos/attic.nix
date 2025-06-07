{ config, pkgs, ... }:
let
  domain = "cache.nixos.asia";
  port = 8080;
in
{
  age.secrets = {
    "attic/env.age" = {
      owner = config.services.atticd.user;
      file = ../../secrets/attic/env.age;
    };
  };

  services.atticd = {
    enable = true;
    environmentFile = config.age.secrets."attic/env.age".path;
    # settings based on <https://github.com/zhaofengli/attic/blob/main/server/src/config-template.toml>
    settings = {
      listen = "127.0.0.1:${builtins.toString port}";

      jwt = { };

      # TODO: atticd.service must wait until postgresql.service is active
      database.url = "postgresql://${config.services.atticd.user}?host=/run/postgresql/";

      api-endpoint = "https://${domain}/";

      storage = {
        type = "s3";
        region = "ap-south-1";
        # TODO: autowire from terranix config
        bucket = "chutney-attic-cache-1";
      };

      compression.type = "zstd";

      # The maximum size of the upload info JSON, in bytes.
      max-nar-info-size = 2048576; # 2 MiB

      # Disable automatic GC:
      garbage-collection.interval = "0s";

      # Data chunking
      #
      # Warning: If you change any of the values here, it will be
      # difficult to reuse existing chunks for newly-uploaded NARs
      # since the cutpoints will be different. As a result, the
      # deduplication ratio will suffer for a while after the change.
      chunking = {
        # The minimum NAR size to trigger chunking
        #
        # If 0, chunking is disabled entirely for newly-uploaded NARs.
        # If 1, all NARs are chunked.
        nar-size-threshold = 64 * 1024; # 64 KiB

        # The preferred minimum size of a chunk, in bytes
        min-size = 16 * 1024; # 16 KiB

        # The preferred average size of a chunk, in bytes
        avg-size = 64 * 1024; # 64 KiB

        # The preferred maximum size of a chunk, in bytes
        max-size = 256 * 1024; # 256 KiB
      };
    };
  };

  services.postgresql = {
    enable = true;
    ensureUsers = [
      {
        name = config.services.atticd.user;
        ensureDBOwnership = true;
      }
    ];
    ensureDatabases = [
      config.services.atticd.user
    ];
    # Allows a local system user to authenticate only if their PostgreSQL username matches their system (Unix) username
    authentication = pkgs.lib.mkOverride 10 ''
      #type database  DBuser  auth-method
      local all       all     peer
    '';
  };

  networking.firewall.allowedTCPPorts = [ 443 80 ];

  # Required for enabling ACME
  security.acme.defaults.email = "shivaraj.bh@juspay.in";
  security.acme.acceptTerms = true;

  services.nginx = {
    enable = true;
    recommendedTlsSettings = true;
    recommendedZstdSettings = true;
    recommendedOptimisation = true;
    recommendedProxySettings = true;
    clientMaxBodySize = "0"; # Remove size restrictions
    virtualHosts.${domain} = {
      enableACME = true;
      forceSSL = true;
      locations."/".proxyPass = "http://127.0.0.1:${builtins.toString port}";
    };
  };

  environment.systemPackages = [
    # Needed for creating root-token using `atticd-atticadm`
    config.services.atticd.package
    (pkgs.writeShellApplication {
      name = "attic-gc-once";
      runtimeInputs = [ config.services.atticd.package ];
      text =
        let
          # `server.toml` file creation based on https://github.com/NixOS/nixpkgs/blob/88efe689298b1863db0310c0a22b3ebb4d04fbc3/nixos/modules/services/networking/atticd.nix#L18
          serverToml = (pkgs.formats.toml { }).generate "server.toml" config.services.atticd.settings;
        in
        ''
          # shellcheck source=/dev/null
          source ${config.services.atticd.environmentFile}
          export ATTIC_SERVER_TOKEN_RS256_SECRET_BASE64
          atticd -f ${serverToml} --mode garbage-collector-once
        '';
    })
  ];
}
