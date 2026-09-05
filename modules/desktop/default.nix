{ lib, pkgs, ... }:
{
  imports = [
    ../common
    ./bluetooth.nix
    ./dms.nix
    ./file-manager.nix
    ./hyprland.nix
    ./greeter.nix
    ./network-manager.nix
    ./peripherals.nix
    ./pipewire.nix
    ./tailscale.nix
    ./theme.nix
  ];

  services.accounts-daemon.enable = true;
  services.printing.enable = true;
  services.upower.enable = true;
  boot.kernelPackages = lib.mkDefault pkgs.linuxPackages_latest;
}
