{
  config,
  inputs,
  lib,
  ...
}:
let
  inherit (lib.lists) singleton;
  inherit (lib.modules) mkForce;
in
{
  imports = [
    ./disko-config.nix
    ./storage-disko.nix
    ./services
    ../../modules/server
    ../../modules/server/ingress-wireguard.nix
    ../../modules/boot.nix
    ../../modules/btop-intel-gpu.nix
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
    imports = singleton ../../home-manager/private/common;
  };

  role = "server"; # Set role of the machine (desktop/server)

  mkAuthentik.google.enable = true;

  mkObservability = {
    enable = true;
    central = true;
    monitoredUnits = [
      "victoriametrics.service"
      "victorialogs.service"
      "vmalert-metrics.service"
      "vmalert-logs.service"
      "alertmanager.service"
      "grafana.service"
      "vmagent.service"
      "vlagent.service"
      "systemd-journal-upload.service"
      "postgresql.service"
    ];
  };

  networking = {
    hostId = "aec20762"; # head --bytes=4 /dev/urandom | od --address-radix=none --format=x4
    useNetworkd = true;
  };

  # CrowdSec's hub setup and the VPN endpoint check need a usable uplink.
  # Ignore Wi-Fi and virtual interfaces when determining network readiness.
  systemd.network.wait-online = {
    enable = mkForce true;
    extraArgs = [
      "--interface=enp2s0:routable"
      "--ipv4"
      "--dns"
    ];
  };

  mkIngressWireguard = {
    enable = true;
    role = "origin";
    peerPublicKey = "W2u4RPtVhqDZVuEKUwr5ogPneM/5BLSwNeU96kiFuDM=";
  };

  boot.zfs.extraPools = singleton "tank";

  # SWAP (ZRAM)
  zramSwap.enable = true;

  system.stateVersion = "26.05";
}
