{
  ec2 = {
    hvm = true;
    efi = true;
  };

  # works around https://github.com/nix-community/nixos-generators/issues/150
  virtualisation.diskSize = "auto";

  # Volume is formatted - if not already - in the terranix configuration of `resource.aws_instance.chutney.user_data`
  fileSystems."/mnt/postgres" = {
    device = "/dev/disk/by-label/postgres-state";
    fsType = "ext4";
  };

  # Contrary to the name, tmpfiles can be used to create persistent files.
  #
  # As we modify the postgresql data directory, we become responsible to initialise it and set the right permissions.
  # Note: We aren't using the root of the mountpoint as dataDir because, in postgresql's words: "initdb: hint: Using a mount point directly as the data directory is not recommended."
  systemd.tmpfiles.settings = {
    "10-postgres-create-dir"."/mnt/postgres/data".d = {
      mode = "0755";
      user = "postgres";
      group = "postgres";
    };
  };
  systemd.services.postgresql.after = [ "systemd-tmpfiles-setup.service" ];

  networking.hostName = "chutney";
  system.stateVersion = "24.11";
}
