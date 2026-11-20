{ config, lib, ... }:
let
  inherit (lib.options) mkOption;
  inherit (lib.types)
    attrsOf
    nullOr
    str
    submodule
    ;
  hostType = submodule {
    options = {
      user = mkOption {
        type = str;
        default = "krokosik";
        description = "Primary user account on this device.";
      };
      tailscale = {
        ipv4 = mkOption {
          type = str;
          description = "Tailscale IPv4 address of this device.";
        };
        ipv6 = mkOption {
          type = str;
          description = "Tailscale IPv6 address of this device.";
        };
      };
      hostKey = mkOption {
        type = nullOr str;
        default = null;
        description = ''
          ED25519 public key of /etc/ssh/ssh_host_ed25519_key, also presented by
          Tailscale SSH. Set it only for devices accepting SSH: each one gets a
          pinned known_hosts entry and a generated ssh_config block.
        '';
      };
      userKey = mkOption {
        type = nullOr str;
        default = null;
        description = "Public key of the primary user's id_ed25519, registered as a read-only GitHub deploy key.";
      };
    };
  };
in
{
  options.nunix = {
    hosts = mkOption {
      type = attrsOf hostType;
      description = "Shared device inventory, identical on every host.";
    };
    self = mkOption {
      type = hostType;
      readOnly = true;
      default = config.nunix.hosts.${config.networking.hostName};
      description = "Inventory entry of the current host. Set values in nunix.hosts instead.";
    };
    tailnetDomain = mkOption {
      type = str;
      default = "chimp-qilin.ts.net";
      description = "Tailscale MagicDNS suffix.";
    };
  };

  config.nunix.hosts = {
    anubis = {
      tailscale = {
        ipv4 = "100.72.36.37";
        ipv6 = "fd7a:115c:a1e0::2c3a:2426";
      };
      hostKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGV4rBomKDF6oD/H0gTHK7kcw2Id36RLQ5SLMy03qUer";
      userKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGUTKDQm7saPW6jNaNQUgrABtzK3M8vQssCCCXLRryrG krokosik@anubis";
    };

    horus = {
      tailscale = {
        ipv4 = "100.122.167.68";
        ipv6 = "fd7a:115c:a1e0::353a:a745";
      };
      userKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKw9/vuQetryM92flnnOazWpHJSfvK9am/JVmUiZLHsu krokosik@horus";
    };

    isis = {
      tailscale = {
        ipv4 = "100.91.232.49";
        ipv6 = "fd7a:115c:a1e0::fd2c:e832";
      };
      userKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPt1+HyL2KLfuEfNmOsSciwfIWmJMrEUAgpHbwg6iyIF krokosik@isis";
    };

    lindbladian = {
      user = "wkrokosz";
      tailscale = {
        ipv4 = "100.72.103.81";
        ipv6 = "fd7a:115c:a1e0::792c:6752";
      };
      userKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICKQ6w8k1Jk8JMK+QZXYgu57e+OChXEoHFiPt7T8PEcE wkrokosz@lindbladian";
    };

    osiris = {
      tailscale = {
        ipv4 = "100.100.250.77";
        ipv6 = "fd7a:115c:a1e0::ec3a:fa4d";
      };
      hostKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICe/ngBcMq4U617INsnKl/8aNqp+zqRe/QmE+cVrfuyL";
      userKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAID7sOgLyyDNodmu4kHYGbFWfKhYIQYRIxBRCBaPTD2vU krokosik@osiris";
    };

    xq-dq72.tailscale = {
      ipv4 = "100.65.12.86";
      ipv6 = "fd7a:115c:a1e0::5e3a:c56";
    };
  };
}
