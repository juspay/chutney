{
  ec2 = {
    hvm = true;
    efi = true;
  };

  # works around https://github.com/nix-community/nixos-generators/issues/150
  virtualisation.diskSize = "auto";

  networking.hostName = "chutney";
  system.stateVersion = "24.11";
}
