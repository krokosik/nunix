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
    ./udmabuf.nix
    ./disko-config.nix
    ./windows.nix
    ./fbcon-fix.nix
    inputs.nixos-hardware.nixosModules.lenovo-legion-15ach6h-nvidia
    ../../modules/boot-limine.nix
    ../../modules/desktop
    ../../modules/desktop/cad.nix
    # Horus is a development host; its containerized services are for development use.
    ../../modules/oci-containers.nix
    ../../modules/hibernation.nix
    ../../modules/media-share.nix
  ];

  # Add the report generated with `run0 nix run github:numtide/nixos-facter --
  # --output hosts/horus/facter.json` before evaluating or deploying this host.
  hardware = {
    # Add the report generated with `run0 nix run github:numtide/nixos-facter --
    # --output hosts/horus/facter.json` before evaluating or deploying this host.
    facter.reportPath = ./facter.json;

    nvidia.branch = "latest";
  };

  role = "desktop";

  services.sunshine = {
    enable = true;
    openFirewall = lib.modules.mkForce false;
  };

  networking.nftables.tables.sunshine = {
    family = "inet";
    content = /* nft */ ''
      chain input {
      type filter hook input priority -10; policy accept;
      iifname "lo" accept
      iifname "tailscale0" ip saddr ${config.tailscaleAddresses.osiris.ipv4} tcp dport { 47984, 47989, 48010 } accept
      iifname "tailscale0" ip saddr ${config.tailscaleAddresses.osiris.ipv4} udp dport { 47998, 47999, 48000 } accept
      iifname "tailscale0" ip6 saddr ${config.tailscaleAddresses.osiris.ipv6} tcp dport { 47984, 47989, 48010 } accept
      iifname "tailscale0" ip6 saddr ${config.tailscaleAddresses.osiris.ipv6} udp dport { 47998, 47999, 48000 } accept
      tcp dport { 47984, 47989, 47990, 48010 } drop
      udp dport { 47998, 47999, 48000 } drop
      }
    '';
  };

  boot = {
    initrd = {
      # we don't use nvidia gpu module, as we let nixos-hardware set the configs
      kernelModules = [
        "nvidia"
        "nvidia_modeset"
        "nvidia_uvm"
        "nvidia_drm"
      ];
    };

    # support building for anubis
    binfmt.emulatedSystems = singleton "aarch64-linux";
  };

  home-manager.users.${config.username} = {
    imports = [
      ../../home-manager/private/desktop
      ./apps
      ../../home-manager/rea.nix
      ../../home-manager/computer-use.nix
      ../../home-manager/agent-workspace.nix
    ];
  };

  system.stateVersion = "26.05";
}
