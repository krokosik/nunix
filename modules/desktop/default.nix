{ lib, ... }:
let
  inherit (lib.lists) singleton;
in
{
  imports = [
    ./aptos.nix
    ../common
    ./bluetooth.nix
    ./brightness.nix
    ./desktop-packages.nix
    ./dms.nix
    ./extra-users.nix
    ./file-manager
    ./flatpak.nix
    ./hyprland.nix
    ./greeter.nix
    ./kdeconnect.nix
    ./network-manager.nix
    ./nix-grpc-store.nix
    ./peripherals.nix
    ./pipewire.nix
    ./plymouth.nix
    ./podman.nix
    ./samba-mounts.nix
    ./tailscale.nix
    ./theme.nix
    ./tlp.nix
    ./voxtype.nix
    ./windows-partition.nix
    ./wine.nix
  ];

  # Every user on a desktop host gets the shared desktop environment
  home-manager.sharedModules = singleton ../../home-manager/shared/desktop;

  services = {
    accounts-daemon.enable = true;
    printing.enable = true;
    upower.enable = true;
  };
}
