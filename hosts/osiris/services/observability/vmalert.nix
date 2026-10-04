{ config, lib, ... }:
let
  inherit (lib.lists) singleton;
  serviceMetricRules = lib.mapAttrs' (
    name: service: lib.nameValuePair "service-${name}" service.metricAlerts
  ) config.mkObservabilityServices;
  serviceLogRules = lib.mapAttrs' (
    name: service: lib.nameValuePair "service-${name}" service.logAlerts
  ) config.mkObservabilityServices;
  # Only declarations in this host evaluation are visible here. Fleet-wide
  # rules are explicitly contributed to mkObservability.metricRules/logRules.
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
  # A log group's interval is also vmalert's default LogsQL look-back window.
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
    # Each process has one datasource URL, so metrics and LogsQL need separate
    # instances. Both notify the same local Alertmanager.
    metrics = {
      enable = true;
      settings = {
        "datasource.url" = vm;
        "notifier.url" =
          singleton "http://127.0.0.1:${toString config.services.prometheus.alertmanager.port}";
        "httpListenAddr" = "127.0.0.1:8880";
        "external.url" = config.mkTraefikServices.vmalert-metrics.fullHostname;
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
        "external.url" = config.mkTraefikServices.vmalert-logs.fullHostname;
        "remoteWrite.url" = vm;
        "remoteRead.url" = vm;
      };
      rules.groups = logGroups;
    };
  };

  mkTraefikServices = lib.genAttrs [ "vmalert-metrics" "vmalert-logs" ] (
    name:
    let
      instance = lib.removePrefix "vmalert-" name;
    in
    {
      host = "127.0.0.1";
      port = lib.toInt (
        lib.lists.last (
          lib.splitString ":" config.services.vmalert.instances.${instance}.settings.httpListenAddr
        )
      );
      chain = [
        "chain-tailscale"
        "chain-authentik"
      ];
    }
  );

  mkAuthentik.forwardAuthApps = lib.genAttrs [ "vmalert-metrics" "vmalert-logs" ] (name: {
    displayName = "VMAlert — ${if name == "vmalert-metrics" then "Metrics" else "Logs"}";
    launchUrl = "${config.mkTraefikServices.${name}.fullHostname}/vmalert/";
    iconUrl = config.mkAuthentik.forwardAuthApps.victoriametrics.iconUrl;
    accessGroup = "admins";
    displayGroup = "Infrastructure";
  });

  mkObservability.hostMetrics = {
    vmalert-metrics.url = "http://127.0.0.1:8880/metrics";
    vmalert-logs.url = "http://127.0.0.1:8881/metrics";
  };
}
