{ config, ... }:
{
  services.victoriametrics = {
    enable = true;
    listenAddress = "127.0.0.1:8428";
    retentionPeriod = "45d";
  };

  mkObservability.hostMetrics.victoriametrics.url = "http://${config.services.victoriametrics.listenAddress}/metrics";
}
