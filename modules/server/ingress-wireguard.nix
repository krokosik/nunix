{ config, lib, ... }:
let
  inherit (lib.attrsets) optionalAttrs;
  inherit (lib.lists) singleton;
  inherit (lib.modules) mkIf;
  inherit (lib.options) mkEnableOption mkOption;
  inherit (lib.types) enum port str;
  inherit (lib.types.ints) between positive;

  cfg = config.mkIngressWireguard;
  isEdge = cfg.role == "edge";
in
{
  options.mkIngressWireguard = {
    enable = mkEnableOption "the dedicated public ingress WireGuard tunnel";

    role = mkOption {
      type = enum [
        "edge"
        "origin"
      ];
      default = "origin";
      description = "Whether this host forwards public traffic or serves it.";
    };

    interface = mkOption {
      type = str;
      default = "wg-ingress";
    };

    uplink = mkOption {
      type = str;
      default = "enp0s6";
      description = "Public interface on the edge host.";
    };

    endpoint = mkOption {
      type = str;
      default = "144.24.185.41";
      description = "Public IPv4 address of the edge host.";
    };

    port = mkOption {
      type = port;
      default = 51820;
    };

    mtu = mkOption {
      type = between 1328 1420;
      default = 1380;
      description = "Inner MTU; accommodates QUIC's 1280-byte datagrams and IP/UDP headers.";
    };

    edgeIPv4 = mkOption {
      type = str;
      default = "10.253.43.1";
    };

    originIPv4 = mkOption {
      type = str;
      default = "10.253.43.2";
    };

    edgeIPv6 = mkOption {
      type = str;
      default = "fd42:6e75:6e69:443::1";
    };

    originIPv6 = mkOption {
      type = str;
      default = "fd42:6e75:6e69:443::2";
    };

    peerPublicKey = mkOption {
      type = str;
      default = "";
    };

    replyTable = mkOption {
      type = positive;
      default = 51820;
      description = "Policy routing table used only by origin tunnel source addresses.";
    };
  };

  config = mkIf cfg.enable {
    assertions = [
      {
        assertion = config.role == "server" && config.networking.useNetworkd;
        message = "Ingress WireGuard requires a server using systemd-networkd.";
      }
      {
        assertion = cfg.peerPublicKey != "";
        message = "Ingress WireGuard requires the peer's public key.";
      }
    ];

    sops.secrets.ingress_wireguard_private_key = {
      key = "wireguard/ingress_private_key";
      owner = "systemd-network";
      mode = "0400";
      restartUnits = singleton "systemd-networkd.service";
    };

    systemd = {
      services.systemd-networkd.after = singleton "sops-install-secrets.service";

      network = {
        netdevs."40-${cfg.interface}" = {
          netdevConfig = {
            Kind = "wireguard";
            Name = cfg.interface;
            MTUBytes = cfg.mtu;
          };

          wireguardConfig = {
            PrivateKeyFile = config.sops.secrets.ingress_wireguard_private_key.path;
            ListenPort = cfg.port;
          };

          wireguardPeers = singleton (
            {
              PublicKey = cfg.peerPublicKey;
              AllowedIPs =
                if isEdge then
                  [
                    "${cfg.originIPv4}/32"
                    "${cfg.originIPv6}/128"
                  ]
                else
                  [
                    "0.0.0.0/0"
                    "::/0"
                  ];
              RouteTable = if isEdge then "main" else cfg.replyTable;
            }
            // optionalAttrs (!isEdge) {
              Endpoint = "${cfg.endpoint}:${toString cfg.port}";
              PersistentKeepalive = 25;
            }
          );
        };

        networks."40-${cfg.interface}" = {
          matchConfig.Name = cfg.interface;
          address =
            if isEdge then
              [
                "${cfg.edgeIPv4}/32"
                "${cfg.edgeIPv6}/128"
              ]
            else
              [
                "${cfg.originIPv4}/32"
                "${cfg.originIPv6}/128"
              ];

          networkConfig = {
            DHCP = "no";
            IPv6AcceptRA = false;
            LinkLocalAddressing = "no";
          };

          linkConfig.RequiredForOnline = "no";

          # Only replies from tunnel addresses use the edge as their gateway.
          routingPolicyRules = mkIf (!isEdge) [
            {
              From = "${cfg.originIPv4}/32";
              Table = cfg.replyTable;
              Priority = 100;
            }
            {
              From = "${cfg.originIPv6}/128";
              Table = cfg.replyTable;
              Priority = 100;
            }
          ];
        };

        # Preserve IPv6 router discovery while forwarding on the edge.
        networks."40-${cfg.uplink}" = mkIf isEdge {
          networkConfig.IPv6AcceptRA = true;
        };
      };
    };

    networking = {
      firewall = {
        interfaces.${cfg.uplink}.allowedUDPPorts = mkIf isEdge (singleton cfg.port);

        filterForward = mkIf isEdge true;

        # The authenticated peer carries Internet source IPs. Do not trust the
        # interface wholesale, and exempt only forwarded QUIC from strict RPF.
        extraReversePathFilterRules = mkIf (!isEdge) /* nftables */ ''
          iifname "${cfg.interface}" ip daddr ${cfg.originIPv4} udp dport 443 accept
          iifname "${cfg.interface}" ip6 daddr ${cfg.originIPv6} udp dport 443 accept
        '';

        extraInputRules = mkIf (!isEdge) /* nftables */ ''
          iifname "${cfg.interface}" ip saddr ${cfg.edgeIPv4} ip daddr ${cfg.originIPv4} tcp dport { 80, 443 } accept
          iifname "${cfg.interface}" ip daddr ${cfg.originIPv4} udp dport 443 accept
          iifname "${cfg.interface}" ip6 daddr ${cfg.originIPv6} udp dport 443 accept
        '';
      };

      # No masquerade: conntrack reverses DNAT on replies routed through the edge.
      nftables.tables.ingress-quic = mkIf isEdge {
        family = "inet";
        content = /* nftables */ ''
          chain prerouting {
            type nat hook prerouting priority dstnat; policy accept;
            iifname "${cfg.uplink}" fib daddr type local meta nfproto ipv4 udp dport 443 counter dnat ip to ${cfg.originIPv4}:443
            iifname "${cfg.uplink}" fib daddr type local meta nfproto ipv6 udp dport 443 counter dnat ip6 to [${cfg.originIPv6}]:443
          }
        '';
      };
    };

    boot.kernel.sysctl = {
      "net.ipv4.ip_forward" = mkIf isEdge 1;
      "net.ipv6.conf.all.forwarding" = mkIf isEdge 1;
    };
  };
}
