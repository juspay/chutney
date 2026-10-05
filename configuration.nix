{
  ec2 = {
    hvm = true;
    efi = true;
  };

  # works around https://github.com/nix-community/nixos-generators/issues/150
  virtualisation.diskSize = "auto";

  networking.hostName = "chutney";

  users.users.root.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFN5Ov2zDIG59/DaYKjT0sMWIY15er1DZCT9SIak07vK" # shivaraj-bh
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAjAcaMLTgi1G0NAWMM+ibKT82nyFWmSZ/FahXcpNb8w" # subanesh-k
  ];

  system.stateVersion = "24.11";
}
