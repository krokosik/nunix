{ config, lib, ... }:
let
  inherit (lib.lists) last singleton;
  inherit (lib.strings) splitString toInt;
in
{
  services.victorialogs = {
    enable = true;
    listenAddress = "127.0.0.1:9428";
    extraOptions = singleton "-retentionPeriod=30d";
  };

  mkObservability.hostMetrics.victorialogs.url = "http://${config.services.victorialogs.listenAddress}/metrics";

  mkTraefikServices.victorialogs = {
    host = "127.0.0.1";
    port = toInt (last (splitString ":" config.services.victorialogs.listenAddress));
    chain = [
      "chain-tailscale"
      "chain-authentik"
    ];
  };

  mkAuthentik.forwardAuthApps.victorialogs = {
    displayName = "VictoriaLogs";
    launchUrl = "${config.mkTraefikServices.victorialogs.fullHostname}/select/vmui/";
    accessGroup = "admins";
    displayGroup = "Infrastructure";
  };
}
