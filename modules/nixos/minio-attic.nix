# Based on https://github.com/zhaofengli/attic/blob/687dd7d607824edf11bf33e3d91038467e7fad43/integration-tests/basic/default.nix#L92C9-L117C9
#
# To be improved in the future after testing in real-world usecases.
{ lib, ... }:
{
  services.minio = {
    enable = true;
  };

  services.atticd.settings = {
    storage = {
      type = "s3";
      endpoint = lib.mkDefault "http://127.0.0.1:9000";
      region = lib.mkDefault "us-east-1";
      bucket = lib.mkDefault "attic";
    };
  };

  # Create the data dir. for the bucket
  systemd.tmpfiles.rules = [
    "d /var/lib/minio/data/attic 0770 minio minio -"
  ];
}
