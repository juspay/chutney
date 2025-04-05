{ config, pkgs, ... }:
let
  # Temporary public IPv4
  domain = "13.235.158.155";
  port = 8080;
in
{
  services.atticd = {
    enable = true;
    environmentFile = "/etc/atticd.env";
    # settings based on <https://github.com/zhaofengli/attic/blob/main/server/src/config-template.toml>
    settings = {
      listen = "127.0.0.1:${builtins.toString port}";

      jwt = { };

      # TODO: atticd.service must wait until postgresql.service is active
      database.url = "postgresql://${config.services.atticd.user}?host=/run/postgresql/";

      api-endpoint = "http://${domain}/";

      storage = {
        type = "s3";
        region = "ap-south-1";
        # TODO: autowire from terranix config
        bucket = "chutney-attic-cache";
      };

      compression.type = "zstd";

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

  services.nginx = {
    enable = true;
    recommendedTlsSettings = true;
    recommendedZstdSettings = true;
    recommendedOptimisation = true;
    recommendedProxySettings = true;
    clientMaxBodySize = "0"; # Remove size restrictions
    virtualHosts.${domain} = {
      # enableACME = true;
      # forceSSL = true;
      locations."/".proxyPass = "http://127.0.0.1:${builtins.toString port}";
    };
  };

  environment.systemPackages = [
    # Needed for creating root-token using `atticd-atticadm`
    config.services.atticd.package
    pkgs.awscli2
    (pkgs.writeShellApplication {
      name = "attic-gc-once";
      # `server.toml` file creation based on https://github.com/NixOS/nixpkgs/blob/88efe689298b1863db0310c0a22b3ebb4d04fbc3/nixos/modules/services/networking/atticd.nix#L18
      text = ''
        # shellcheck source=/dev/null
        source ${config.environment.etc."atticd.env".source}
        export ATTIC_SERVER_TOKEN_RS256_SECRET_BASE64
        atticd -f ${(pkgs.formats.toml {}).generate "server.toml" config.services.atticd.settings} --mode garbage-collector-once
      '';
    })
  ];

  # For testing only - Replace with secrets management
  environment.etc."atticd.env".text = ''
    ATTIC_SERVER_TOKEN_RS256_SECRET_BASE64='LS0tLS1CRUdJTiBSU0EgUFJJVkFURSBLRVktLS0tLQpNSUlKS1FJQkFBS0NBZ0VBb0xMZDR4d0pjTkZVNjZjdjZSTHB1bWxBMjQzREdMdWNZellZNFJyYUJBbVBNbEhxCmhCWEtEQkhvV0l0dyt6b3BwWGVHdmdJM0JYTVR4cWRTczFxakJZZEhzWEgrMDArbWNxayttNFNGVzFIYmg0MXUKNDRFbVYrYVJOaEVBK01HVGYwcDBrRGVJS1M0MVYwS2lxUXhkSEdNbk11bVlMb3p0SS9RMTFlV1dFRVQrRGoxQwp6clcvMmkrSVRWRnp1WUUxY01aMmpmQjNGUUl5SktCSWlnckMxYzB4WE5pQndhd2dtdnNLRzNBMzkza3JRU1VBClA2dHowOU5ZRlMyK0txV1NVZVRYUTJLUmVjd0FMN1B6WjRGcUpmaCs5M1VZZ29ma0cwRmZ6UVpjKzJIamdnVVYKTkJMbHp6VzlURDFVQWYxN2ozMEdWRlREYmh5a0NRZ08weWdFSUczTzlJMmcvMVRPRk15ak9zOU1nUkYzUktPdwovZ09LaWpoOUJyc2ViMUU1V0I5VDdrcXg4ck9MU2NPSHBYclJveUsxdmkrem9oa09mbE15dldzemlkUEtuYisvCkI0Z0g4V0ZyVVRmTmZUQjZMRDlIbEZOR216R3JYQUUxV3lVMjdTN2YvbDJveWhnVEI2QURTakpRYXRoeHZDOHIKZmc2Z1Y3bHYya21KclZvQWp6WmFVWlFqQnVyRnNZWjYwY3BvTzJnY0ZjUDg1d0QyNkN1SWc2ZkxTNm5YcE9aYwphdGxJdUxFODB3eFhPMCttbmRtb1lkNjZZd3RLZzBJQ2RlVi9remhpTDdKaTFCYUszMkw1ckVDeEZaOXZ3STdyCkl4dnRveUkxRlZpWHhRVmxRS1lSSlhVam5LbnV1U2RMMUJJZ2NnYkpHd3RwbG10MTA4WUthZUVoMFFrQ0F3RUEKQVFLQ0FnQkc4N0tVZStTUE0xM1RUbFlSQ3BDNEJaRGxYNG9zZVdsclJJOW5sSHQrSE5wazFWWStTNENTSTdYNgpvbGFZRmU0ZGFORE5SQjBYQXVCUWJjQk9BRTdLT2hpbGVEZVRCUy93b0ZsTVFRN0FhendLZFovb1F6V3l5ZEtECmxLNWhKdGNBOU5iU2RqSmdQRTdBNEdNQlVMd3J0SHV5TndGQ1RHYkg0U09EOVlKMFhJSHZ0NHl2eC8rVlRqZFkKTEFaMGVXQW5FdmwxWWg2eDMrNVR6WkU1b2RhMG40eVQrZVFRcHZjZWRvalg1SXhSYitaeE5PMFBMNXhNZ3B2NQpmZURnNDRuZkxyTDh4YUNGcmxUR3V5VlZKZ2JBRFIvQ0VxbG51S2cyZ0g3VC8yTStldElBcmszV1dDR3ZnNEs1CkRycnd4Z0t3TC91RGNJbDVMSndnZ0xaSzlQZ2N4VVo3ZnZMMEF6NzcvWUJYenRxMTgvdGNMU0tMbjhhNmF6YmUKeHF6U1BSd1FHc1FQU1pnU0tBV2J6RTBMSnN0ZktQejNpTU02aDlaQ25KTGJudGFpajgwbUZXQmNKOHY5UHFYWApGUTNmVjZrZXRIUVA1YUhDVEtCOE1uZzRvU0E1bDhuaUFlbllab1BVeDNKaXB4OWtPU1FkN0E4MXpIVjV5T1R2CmhOQlNRL0daZUJRMTV5NGlTSytHaklrcnczYXRML3BFUWhMdVRINUlSMHBqWW1UVWlickpWUzN0T2FScGFGQloKR2VBMm1xcU5Db1Z0K2pNcmlZcjBlVEVobWNnUUNJMGVFYk5DRG5ob3JtSDBWcklHNEpDQ0tKTFZGWmVrS05wZQpKOEFqN0hDS2pRMm4wUTM0RzhSY3FOaTlVeXhWNWxqTVF0ays3bkxEN1BqbXhMaTBvUUtDQVFFQTRVZFFvN051Cms1eHN4bDhVcSs4R1ZOV1NHb0x6TlkvdHBRZXBZYnpHRGFwUjRJa2kxTjU1WjAvek9zQzBlOEpXM053b3A0UTYKTlBrZ2EwOVNGVms2ZnhDWXB5RXVOSXJZZldCMGk0T0htTWhSRi8vRm1HVm83WWVFbVhDVTBXcnFCQ20zTC9vegpOY1RlcnVvelFiYlRvZUZ5Q0VUUDVlRDRPY28xUmtRVVBOU1E0SGpKWkVWWFAwTlgyQmJsamJTUGlzbEF1OGxDCnpYd25tNkMvYTdrWDZnanIzdERsR1c4YXg4OURuU01NRklhcDFCSzFtMWV3SG56M0xUbndGSTczSXhPRUZIalUKUUQ0N2JkOFNySEw5V21QOUpiOFpJK0hlTUsrR1JQc0pTSTJxaHdJcjdQYXJSVHIycWozSjRMeTF3K3AyaW9HSQpyL1BBYUNaOFhwKzFQd0tDQVFFQXRwMENFZHdnelRNVUljS1VqcVFBWUFzNWJxWmJMOFdVajZBR2h4SlA3U2UyCi9FdTdhaWRQcmg1SkkvdSs3RkVqZDMreFhneHB0RHMxOW11RmdmOWlkRjNRKzJaR2lKSHVpdnBSL3RkNVpxUnMKUkh5anJzTWQ1WTYxRFdzU3J3VlJUZTJjRTc1YUozelg4YXZ1M2VXVFVOR2dBTFQ2ZnJabVlON1VJbnhqTndyQQpVZkFoUDFTVUU5RjhVM0hLM0RZYmZkbXlCNlNHK2E5ZU5DZW5oeGU3Y1BmUktpbFZhYUVjSXMvL21KakJFNThBCkZHMEs1U3ZkNm1qcmhjT3ZhRDhEc2ZZMkl6NzRHMjAwa0xnTjdqYmxwQ3p1Ly9RVFBLaGlFRktidWhnMDNmODYKKzJLWEJaeWVXMUh4T2RiOTE5ZVdjVStVVllyVEljUUV5ZjZsK2JOL3R3S0NBUUVBdWdDbTdUSzJodnd0dDdCRApvaDR0elJlMWxWd3ZzVGJRRVdWOURlek9YZlFWdkYyZU84SWczUk5mRVZDUTlHb21UQjhmRmdrUUFqTDcrSDQ2Cm1OUGVmNUZWYVJEMVZINmJkeEdQeUsxbDVOam9VL2RqejR0VGttTkZNV2VLQ0VyTlEzaXAvdHdITWtzRlRjaWoKWDR1enUwSW9ZL2xrNmpuUTJlNUNCRzByaEhwQjBJVUtTMWNSVFhPdDhRWWVyTnk3Yyt6dEhOOTAzN0syQlVJNQpLcGxkekdkblVNYUxrbTl3M2k4Y2RYNjlkNmtrU2F6VTg1ajRHb1ExbGNyemxoWGdxYjV3WEhMVFZPUE5MODl5ClhKNW8zeHdWcFBmZXF3alA2c1RTQ054NDhzVzlXZEdLTVJJTm9aQ29uekY3SUtyUExSN0dsMStTV3l6WDNXYUIKWTZOY0F3S0NBUUJtM205cURDeldLeTN1RHFTTTdjbmdVTEpicUk2NWpIMnhvcDNLdlFBVlFrZ01POFVwZVZlagphQ0FmaXhMMElJandLaGlLT0VmYlpYZHlod05BUmRMNlpsYnhKNTRZRk16aHNUMDdaN3BWbmMzM2pwYk9QYys3Cm52WlN4cnhScDVjelpPU0ZJcmU2Z3ROS3FtWDJ6ZnA4am5tcHJFbG4wK3c4S1lvcW14TncwRGVpY0xqcDZnVTQKWE12Q1hkbSt6eVFSY3U2YzY0dTFYNXFibXJMK29OblFPMm15YkhKVy9KRFM4NFN5TzJxWVdQczhobWlhekdsSQpRUzVidmU0enRUdXBwbDY4NEIzM3BUNzFQeGxwMWJickV2elhabkRudkpyeFF2ZkNqeHhJNmh3WnZHSUNvVVY3CmY5OTVpNmlYVERUTlE5ejFpeXlBV3VHdndDbFRUbEJsQW9JQkFRQ0xrK3BLODRZSWx0Uk0wekdRNVZTQ2xTb1YKWnZHQ09UeUhhZlRSTUJLTUJDTzJoL1NwNDJhSGt2Y2FJZkFwakN3TXV6WmdlK1pRNW9wSTJmeDcyZmxTWThZNQpDU3pXKzVva3hBeTBLdUw5K3JpbFN0bGIxNFNZVDlqakduRVlSY3gvcHhBNmt0TUsyWHFIN0Z1d0x0d3FLUVlwCm0zeUxGZEgrQjNNaC9tK0lyeFV0QS8vQTVqVTJMeHk3czNlWCtQM1N2dzB2bkNCTEV1aDNIaVQvOWNEN1EyTHEKMXdibEszVWN6eTBhbWFBS2ZqK3QvK3paY2tYRk5vS1RiK21QdDJHT1l1TzlnVjI2N2Q0cVNCLzZOQkFNTWdQMApVejhkZzdkK1Q4TWVjcE04eUgzcW53Wm4weXZwZmRYQ1c5YTRSMnNZTW5FemwwR3ZOdnlXaytQWklYRncKLS0tLS1FTkQgUlNBIFBSSVZBVEUgS0VZLS0tLS0K'
  '';
}
