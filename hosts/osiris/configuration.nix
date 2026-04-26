{
  config,
  inputs,
  ...
}:
{
  imports = [
    # Include the results of the hardware scan.
    ./disko-config.nix
    ./hardware-configuration.nix
    ../../modules/boot.nix
    #../modules/boot-grub.nix  # Grub required for Hetzner VPS CHANGEME
    ../../modules/common
    ../../modules/zfs.nix
    ../../home-manager/home-manager.nix
    inputs.disko.nixosModules.disko
    inputs.home-manager.nixosModules.home-manager
    inputs.sops-nix.nixosModules.sops
  ];

  isVirtual = true; # Define if a VPS/VM or container
  latestZFSKernel = true; # Set to use latest available ZFS compatible kernel

  home-manager.users.${config.username} = {
    imports = [
      ../../home-manager/base.nix
    ];
  };

  networking.hostName = "osiris";
  networking.hostId = "aec20762"; # head -c4 /dev/urandom | od -A none -t x4
  networking.networkmanager.enable = true;

  # Swap (zram)
  zramSwap.enable = true;

  system.stateVersion = "25.11";
}