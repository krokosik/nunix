{ lib, ... }:
let
  inherit (lib.options) mkOption;
  inherit (lib.types) attrsOf str submodule;
in
{
  options.tailscaleAddresses = mkOption {
    type = attrsOf (submodule {
      options = {
        ipv4 = mkOption {
          type = str;
          description = "Tailscale IPv4 address of this device.";
        };
        ipv6 = mkOption {
          type = str;
          description = "Tailscale IPv6 address of this device.";
        };
      };
    });
    description = "Shared Tailscale device address inventory, available on every host.";
    default = {
      anubis = {
        ipv4 = "100.72.36.37";
        ipv6 = "fd7a:115c:a1e0::2c3a:2426";
      };
      horus = {
        ipv4 = "100.122.167.68";
        ipv6 = "fd7a:115c:a1e0::353a:a745";
      };
      isis = {
        ipv4 = "100.91.232.49";
        ipv6 = "fd7a:115c:a1e0::fd2c:e832";
      };
      lindbladian = {
        ipv4 = "100.72.103.81";
        ipv6 = "fd7a:115c:a1e0::792c:6752";
      };
      osiris = {
        ipv4 = "100.100.250.77";
        ipv6 = "fd7a:115c:a1e0::ec3a:fa4d";
      };
      xq-dq72 = {
        ipv4 = "100.65.12.86";
        ipv6 = "fd7a:115c:a1e0::5e3a:c56";
      };
    };
  };
}
