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
    ./network-manager.nix
    ./peripherals.nix
    ./pipewire.nix
    ./plymouth.nix
    ./samba-mounts.nix
    ./sunshine.nix
    ./tailscale.nix
    ./theme.nix
    ./tlp.nix
    ./windows-partition.nix
    ./wine.nix
  ];

  services = {
    accounts-daemon.enable = true;
    printing.enable = true;
    upower.enable = true;
  };
}
