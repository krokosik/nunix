{ lib, ... }:
let
  inherit (lib.lists) singleton;
in
{
  home-manager.sharedModules = singleton { services.kdeconnect.enable = true; };

  networking.firewall.extraInputRules = /* nftables */ ''
    ip saddr { 10.0.0.0/8, 172.16.0.0/12, 192.168.0.0/16, 169.254.0.0/16 } meta l4proto { tcp, udp } th dport 1714-1764 accept
    ip6 saddr { fc00::/7, fe80::/10 } meta l4proto { tcp, udp } th dport 1714-1764 accept
  '';
}
