{
  config,
  lib,
  ...
}:
let
  inherit (lib) mkIf;
in
{
  networking.firewall = {
    enable = true;

    # Tailscale and NetworkManager WireGuard can alter packet marks, making strict
    # reverse-path checks drop VPN replies arriving on the physical interface.
    checkReversePath = mkIf config.networking.networkmanager.enable "loose";
  };

  networking.nftables.enable = true;

  # Optimization: Prevent systemd from waiting for network online
  # (Optional but recommended for faster boot with VPNs)
  systemd.network.wait-online.enable = false;
  boot.initrd.systemd.network.wait-online.enable = false;
}
