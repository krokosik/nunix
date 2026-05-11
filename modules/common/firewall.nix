{ config, ... }:
{
  networking.firewall = {
    enable = true;
    trustedInterfaces = [ "tailscale0" ];
    allowedUDPPorts = [ config.services.tailscale.port ];
  };

  networking.nftables = {
    enable = true;

    # Allow Docker DNS traffic to local DNS server
    ruleset = ''
      table inet filter {
        chain input {
          ip saddr 172.16.0.0/12 ip daddr 172.17.0.1 udp dport 53 accept
        }
      }
    '';
  };

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
