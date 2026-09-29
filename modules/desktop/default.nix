{
  imports = [
    ../common
    ./bluetooth.nix
    ./dms.nix
    ./extra-users.nix
    ./file-manager.nix
    ./hyprland.nix
    ./greeter.nix
    ./network-manager.nix
    ./peripherals.nix
    ./pipewire.nix
    ./plymouth.nix
    ./sunshine.nix
    ./tailscale.nix
    ./theme.nix
    ./tlp.nix
  ];

  services.accounts-daemon.enable = true;
  services.printing.enable = true;
  services.upower.enable = true;
}
