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
    ../../modules/server/ingress-wireguard.nix
    ../../modules/boot.nix
    ../../modules/zfs.nix
    ../../home-manager/home-manager.nix
  ];

  hardware.facter.reportPath = ./facter.json;

  isVirtual = true; # Define if a VPS/VM or container
  latestZFSKernel = true; # Set to use latest available ZFS compatible kernel

  home-manager.users.${config.username} = {
    imports = [
      ../../home-manager/shared/common
    ];
  };

  role = "server"; # Set role of the machine (desktop/server)

  mkObservability.enable = true;
  mkObservability.monitoredUnits = [
    "vmagent.service"
    "vlagent.service"
    "systemd-journal-upload.service"
  ];

  networking.hostId = "98165cf2"; # head -c4 /dev/urandom | od -A none -t x4
  networking.useNetworkd = true;

  mkIngressWireguard = {
    enable = true;
    role = "edge";
    peerPublicKey = "luBECxE+b9Wuck66WXQdwzfRzUvlHqu8/goArANV+HU=";
  };

  # Swap (zram)
  zramSwap.enable = true;

  system.stateVersion = "26.05";
}
