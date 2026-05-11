{ config, ... }:
{
  networking.firewall = {
    enable = true;
    trustedInterfaces = [ "tailscale0" ];
    allowedUDPPorts = [ config.services.tailscale.port ];
    extraInputRules = ''
      ip saddr 172.16.0.0/12 udp dport 53 accept
      ip saddr 172.16.0.0/12 tcp dport 53 accept
      ip saddr 192.168.90.0/24 udp dport 53 accept
      ip saddr 192.168.90.0/24 tcp dport 53 accept
      ip saddr 192.168.91.0/24 udp dport 53 accept
      ip saddr 192.168.91.0/24 tcp dport 53 accept
    '';
  };

  networking.nftables.enable = true;

  # Force tailscaled to use nftables (Critical for clean nftables-only systems)
  # This avoids the "iptables-compat" translation layer issues.
  systemd.services.tailscaled.serviceConfig.Environment = [
    "TS_DEBUG_FIREWALL_MODE=nftables"
  ];

  # Optimization: Prevent systemd from waiting for network online
  # (Optional but recommended for faster boot with VPNs)
  systemd.network.wait-online.enable = false;
  boot.initrd.systemd.network.wait-online.enable = false;
}
