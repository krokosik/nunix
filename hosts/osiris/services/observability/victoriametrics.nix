{ config, lib, ... }:
{
  services.victoriametrics = {
    enable = true;
    listenAddress = "127.0.0.1:8428";
    retentionPeriod = "45d";
  };

  mkObservability.hostMetrics.victoriametrics.url = "http://${config.services.victoriametrics.listenAddress}/metrics";

  mkTraefikServices.victoriametrics = {
    host = "127.0.0.1";
    port = lib.toInt (
      lib.lists.last (lib.splitString ":" config.services.victoriametrics.listenAddress)
    );
    chain = [
      "chain-tailscale"
      "chain-authentik"
    ];
  };

  mkAuthentik.forwardAuthApps.victoriametrics = {
    displayName = "VictoriaMetrics";
    launchUrl = "${config.mkTraefikServices.victoriametrics.fullHostname}/vmui/";
    accessGroup = "admins";
    displayGroup = "Infrastructure";
  };
}
