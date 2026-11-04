{
  config,
  inputs,
  lib,
  ...
}:
let
  inherit (lib.lists) singleton;
  inherit (lib.modules) mkForce;
in
{
  imports = singleton ../common/tailscale.nix;

  services = {
    tailscale = {
      authKeyFile = config.sops.secrets.tailscale_server_auth_key.path;
      extraUpFlags = [
        "--ssh"
        "--advertise-tags=tag:server"
      ];
    };

    # Never generate remediation decisions for authenticated tailnet peers.
    crowdsec.localConfig.parsers.s02Enrich = singleton {
      name = "local/tailnet-whitelist";
      description = "Whitelist authenticated tailnet traffic";
      whitelist = {
        reason = "Tailnet peer";
        cidr = [
          "100.64.0.0/10"
          "fd7a:115c:a1e0::/48"
        ];
      };
    };
  };

  systemd.services.tailscaled-autoconnect = {
    startLimitIntervalSec = mkForce 0;
    serviceConfig = {
      Restart = "on-failure";
      RestartSec = "30s";
    };
  };

  sops.secrets.tailscale_server_auth_key = {
    sopsFile = "${inputs.my-secrets}/server/secrets.yaml";
    owner = "root";
    mode = "0400";
  };
}
