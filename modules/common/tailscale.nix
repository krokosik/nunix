{
  config,
  lib,
  ...
}:
let
  inherit (lib.lists) singleton;
in
{
  services.tailscale.enable = true;

  networking.firewall = {
    trustedInterfaces = singleton "tailscale0";
    allowedUDPPorts = singleton config.services.tailscale.port;
  };

  systemd.services.tailscaled.serviceConfig.Environment = singleton "TS_DEBUG_FIREWALL_MODE=nftables";
}
