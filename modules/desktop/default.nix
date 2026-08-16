{
  imports = [
    ./bluetooth.nix
    ./dms.nix
    ./file-manager.nix
    ./hyprland.nix
    ./keyring.nix
    ./network-manager.nix
    ./peripherals.nix
    ./pipewire.nix
    ./tailscale.nix
  ];

  services.accounts-daemon.enable = true;
  services.printing.enable = true;
  services.upower.enable = true;
}
