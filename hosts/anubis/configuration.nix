{
  config,
  inputs,
  ...
}:
{
  imports = [
    ./disko-config.nix
    ./services
    ../../modules/common
    ../../modules/server
    ../../modules/avahi.nix
    ../../modules/boot.nix
    ../../modules/zfs.nix
    ../../home-manager/home-manager.nix
    inputs.disko.nixosModules.disko
    inputs.home-manager.nixosModules.home-manager
    inputs.sops-nix.nixosModules.sops
  ];

  hardware.facter.reportPath = ./facter.json;

  isVirtual = true; # Define if a VPS/VM or container
  latestZFSKernel = true; # Set to use latest available ZFS compatible kernel

  home-manager.users.${config.username} = {
    imports = [
      ../../home-manager/base.nix
    ];
  };

  role = "server"; # Set role of the machine (desktop/shared/server)

  networking.hostId = "98165cf2"; # head -c4 /dev/urandom | od -A none -t x4
  networking.useNetworkd = true;
  networking.useDHCP = false; # adresses are assigned by Oracle

  # Swap (zram)
  zramSwap.enable = true;

  system.stateVersion = "26.05";
}
