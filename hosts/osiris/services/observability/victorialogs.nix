{ config, ... }:
{
  services.victorialogs = {
    enable = true;
    listenAddress = "127.0.0.1:9428";
    extraOptions = [ "-retentionPeriod=30d" ];
  };

  mkObservability.hostMetrics.victorialogs.url = "http://${config.services.victorialogs.listenAddress}/metrics";
}
