{
  config,
  inputs,
  ...
}:
{
  imports = [
    ./disko-config.nix
    ./services
    ../../modules/server
    ../../modules/boot.nix
    ../../modules/disable-deep-sleep.nix
    ../../modules/oci-containers.nix
    ../../modules/intel-gpu.nix
    ../../modules/zfs.nix
    inputs.nixos-hardware.nixosModules.common-pc-ssd
    inputs.nixflix.nixosModules.default
    inputs.niks3.nixosModules.default
  ];

  hardware.facter.reportPath = ./facter.json;

  isVirtual = false; # Define if a VPS/VM or container
  latestZFSKernel = true; # Set to use latest available ZFS compatible kernel

  home-manager.users.${config.username} = {
    imports = [
      ../../home-manager/base.nix
    ];
  };

  role = "server"; # Set role of the machine (desktop/shared/server)

  networking.hostId = "aec20762"; # head -c4 /dev/urandom | od -A none -t x4
  networking.useNetworkd = true;

  # Swap (zram)
  zramSwap.enable = true;

  system.stateVersion = "26.05";
}
