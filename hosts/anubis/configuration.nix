{
  config,
  lib,
  inputs,
  ...
}:
let
  inherit (lib.lists) singleton;
in
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
    imports = singleton ../../home-manager/shared/common;
  };

  role = "server"; # Set role of the machine (desktop/server)

  mkObservability = {
    enable = true;
    monitoredUnits = [
      "vmagent.service"
      "vlagent.service"
      "systemd-journal-upload.service"
    ];
  };

  networking = {
    hostId = "98165cf2"; # head --bytes=4 /dev/urandom | od --address-radix=none --format=x4
    useNetworkd = true;
  };

  mkIngressWireguard = {
    enable = true;
    role = "edge";
    peerPublicKey = "luBECxE+b9Wuck66WXQdwzfRzUvlHqu8/goArANV+HU=";
  };

  # SWAP (ZRAM)
  zramSwap.enable = true;

  system.stateVersion = "26.05";
}
