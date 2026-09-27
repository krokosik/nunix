{ config, lib, ... }:
let
  inherit (lib.lists) singleton;
  serviceMetricRules = lib.mapAttrs' (
    name: service: lib.nameValuePair "service-${name}" service.metricAlerts
  ) config.mkObservabilityServices;
  serviceLogRules = lib.mapAttrs' (
    name: service: lib.nameValuePair "service-${name}" service.logAlerts
  ) config.mkObservabilityServices;
  metricGroups =
    lib.mapAttrsToList
      (name: rules: {
        name = "${name}-metrics";
        interval = "30s";
        inherit rules;
      })
      (
        lib.filterAttrs (_: rules: rules != [ ]) (config.mkObservability.metricRules // serviceMetricRules)
      );
  logRules = config.mkObservability.logRules // serviceLogRules;
  logGroups = lib.concatMap (
    name:
    lib.imap0 (index: entry: {
      name = "${name}-logs-${toString index}";
      type = "vlogs";
      inherit (entry) interval;
      rules = singleton (lib.removeAttrs entry [ "interval" ]);
    }) (logRules.${name})
  ) (lib.attrNames logRules);
  vm = "http://${config.services.victoriametrics.listenAddress}";
in
{
  services.vmalert.instances = {
    metrics = {
      enable = true;
      settings = {
        "datasource.url" = vm;
        "notifier.url" =
          singleton "http://127.0.0.1:${toString config.services.prometheus.alertmanager.port}";
        "httpListenAddr" = "127.0.0.1:8880";
        "remoteWrite.url" = vm;
        "remoteRead.url" = vm;
      };
      rules.groups = metricGroups;
    };
    logs = {
      enable = true;
      settings = {
        "datasource.url" = "http://${config.services.victorialogs.listenAddress}";
        "notifier.url" =
          singleton "http://127.0.0.1:${toString config.services.prometheus.alertmanager.port}";
        "httpListenAddr" = "127.0.0.1:8881";
        "remoteWrite.url" = vm;
        "remoteRead.url" = vm;
      };
      rules.groups = logGroups;
    };
  };

  mkObservability.hostMetrics = {
    vmalert-metrics.url = "http://127.0.0.1:8880/metrics";
    vmalert-logs.url = "http://127.0.0.1:8881/metrics";
  };
}
