{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
let
  inherit (lib.attrsets)
    attrNames
    attrValues
    concatMapAttrs
    filterAttrs
    listToAttrs
    mapAttrs'
    mapAttrsToList
    nameValuePair
    optionalAttrs
    ;
  inherit (lib.lists)
    all
    concatLists
    concatMap
    elem
    elemAt
    head
    last
    optional
    optionals
    singleton
    unique
    ;
  inherit (lib.modules) mkIf;
  inherit (lib.options) mkEnableOption mkOption;
  inherit (lib.strings)
    concatMapStrings
    concatStringsSep
    escapeRegex
    match
    splitString
    toJSON
    ;
  inherit (lib.types)
    attrsOf
    bool
    enum
    listOf
    nonEmptyStr
    nullOr
    str
    submodule
    ;
  cfg = config.mkObservability;
  services = config.mkObservabilityServices;
  host = config.networking.hostName;
  loopback = "127.0.0.1";

  ruleType = submodule {
    options = {
      alert = mkOption { type = nonEmptyStr; };
      expr = mkOption { type = nonEmptyStr; };
      for = mkOption {
        type = str;
        default = "0s";
      };
      labels = mkOption {
        type = attrsOf str;
        default = { };
      };
      annotations = mkOption {
        type = attrsOf str;
        default = { };
      };
    };
  };

  endpointType = submodule {
    options = {
      url = mkOption { type = str; };
      interval = mkOption {
        type = str;
        default = "30s";
      };
      labels = mkOption {
        type = attrsOf str;
        default = { };
      };
    };
  };

  logRuleType = submodule {
    options = {
      alert = mkOption { type = nonEmptyStr; };
      expr = mkOption { type = nonEmptyStr; };
      interval = mkOption {
        type = str;
        default = "5m";
      };
      for = mkOption {
        type = str;
        default = "0s";
      };
      labels = mkOption {
        type = attrsOf str;
        default = { };
      };
      annotations = mkOption {
        type = attrsOf str;
        default = { };
      };
    };
  };

  localTargets = mapAttrs' (name: endpoint: nameValuePair "host/${name}" endpoint) cfg.hostMetrics;
  serviceTargets = concatMapAttrs (
    name: service:
    optionalAttrs (service.metrics != null) {
      "service/${name}" = service.metrics;
    }
  ) services;
  postgresTarget = optionalAttrs (config.services.postgresql.enable && cfg.enable) {
    "host/postgres" = {
      url = "http://${loopback}:${toString config.services.prometheus.exporters.postgres.port}/metrics";
      interval = "30s";
      labels = { };
    };
  };
  smartTarget = optionalAttrs (!config.isVirtual && cfg.enable) {
    "host/smartctl" = {
      url = "http://${loopback}:${toString config.services.prometheus.exporters.smartctl.port}/metrics";
      interval = "60s";
      labels = { };
    };
  };
  # Agents see declarations from this host only. Nothing here evaluates or
  # imports another nixosConfiguration to discover its services.
  scrapeTargets = localTargets // serviceTargets // postgresTarget // smartTarget;

  scrapeJobs = mapAttrsToList (
    name: endpoint:
    let
      parsed = match "(https?)://([^/]+)(/.*)?" endpoint.url;
      scheme = elemAt parsed 0;
      address = elemAt parsed 1;
      path = elemAt parsed 2;
    in
    {
      job_name = name;
      inherit scheme;
      metrics_path = if path == null then "/metrics" else path;
      scrape_interval = endpoint.interval;
      static_configs = singleton {
        targets = singleton address;
        labels = endpoint.labels // {
          service = last (splitString "/" name);
        };
      };
    }
  ) scrapeTargets;

  probes = concatMapAttrs (
    name: service:
    mapAttrs' (probeName: probe: nameValuePair "${name}/${probeName}" probe) service.probes
  ) services;
  probeFamilies = probe: optional probe.checkIPv4 "4" ++ optional probe.checkIPv6 "6";
  probeJobs = concatLists (
    mapAttrsToList (
      name: probe:
      map (family: {
        job_name = "probe/${name}/ip${family}";
        metrics_path = "/probe";
        scrape_interval = probe.interval;
        params.module = singleton "${probe.module}_ip${family}";
        static_configs = singleton {
          targets = singleton probe.url;
          labels = probe.labels // {
            service = head (splitString "/" name);
            check = last (splitString "/" name);
            ip_family = family;
            vantage = host;
          };
        };
        relabel_configs = [
          {
            source_labels = singleton "__address__";
            target_label = "__param_target";
          }
          {
            source_labels = singleton "__param_target";
            target_label = "instance";
          }
          {
            target_label = "__address__";
            replacement = "${loopback}:${toString config.services.prometheus.exporters.blackbox.port}";
          }
        ];
      }) (probeFamilies probe)
    ) probes
  );

  probeModules = {
    http_2xx = {
      prober = "http";
      timeout = "10s";
      http = {
        valid_status_codes = [ ];
        follow_redirects = true;
      };
    };
    http_reachable = {
      prober = "http";
      timeout = "10s";
      http = {
        valid_status_codes = [
          200
          302
          401
        ];
        follow_redirects = false;
      };
    };
    tcp_connect.prober = "tcp";
    icmp_ping.prober = "icmp";
  };
  blackboxModules = concatMapAttrs (
    name: module:
    listToAttrs (
      map
        (
          family:
          nameValuePair "${name}_ip${family}" (
            module
            // {
              ${module.prober} = (module.${module.prober} or { }) // {
                preferred_ip_protocol = "ip${family}";
                ip_protocol_fallback = false;
              };
            }
          )
        )
        [
          "4"
          "6"
        ]
    )
  ) probeModules;
  monitoredUnits = unique (
    cfg.monitoredUnits
    ++ cfg.inactiveAlertUnits
    ++ concatMap ({ units, ... }: units) (attrValues services)
  );
  writableFilesystems = filterAttrs (
    _:
    { fsType, options, ... }:
    elem fsType [
      "zfs"
      "ext4"
      "ext3"
      "ext2"
      "xfs"
      "btrfs"
      "vfat"
      "f2fs"
    ]
    && !elem "ro" options
  ) config.fileSystems;
  expectedPools = unique (
    config.boot.zfs.extraPools
    ++ map ({ device, ... }: head (splitString "/" device)) (
      attrValues (filterAttrs (_: { fsType, ... }: fsType == "zfs") config.fileSystems)
    )
  );
  # These declarations travel with each host's metrics, without evaluating
  # another host or maintaining a second inventory in the central rules.
  expectationMetrics = pkgs.writeTextDir "expectations.prom" (
    /* prometheus */ ''
      # HELP node_expected_filesystem_writable Configured persistent writable mountpoint.
      # TYPE node_expected_filesystem_writable gauge
    ''
    + concatMapStrings (mountpoint: /* prometheus */ ''
      node_expected_filesystem_writable{mountpoint=${toJSON mountpoint}} 1
    '') (attrNames writableFilesystems)
    + /* prometheus */ ''
      # HELP node_expected_zfs_pool Configured ZFS pool.
      # TYPE node_expected_zfs_pool gauge
    ''
    + concatMapStrings (pool: /* prometheus */ ''
      node_expected_zfs_pool{zpool=${toJSON pool}} 1
    '') expectedPools
    + /* prometheus */ ''
      # HELP node_expected_systemd_unit_active Systemd unit expected to remain active.
      # TYPE node_expected_systemd_unit_active gauge
    ''
    + concatMapStrings (unit: /* prometheus */ ''
      node_expected_systemd_unit_active{name=${toJSON unit}} 1
    '') cfg.inactiveAlertUnits
  );
  remoteMetricsUrl = "https://metrics-ingest.${config.privateDomain}/api/v1/write";
  remoteLogsUrl = "https://logs-ingest.${config.privateDomain}/insert/native";
in
{
  options = {
    mkObservability = {
      enable = mkEnableOption "host-local metrics and journal forwarding";
      environment = mkOption {
        type = str;
        default = "home";
      };
      central = mkOption {
        type = bool;
        default = false;
        description = "Run the Victoria stores and centralized alerting on this host.";
      };
      hostMetrics = mkOption {
        type = attrsOf endpointType;
        default = { };
        description = "Host-level exporter and infrastructure scrape endpoints.";
      };
      monitoredUnits = mkOption {
        type = listOf str;
        default = [ ];
        description = "Host infrastructure units tracked by the node exporter.";
      };
      repeatedErrorUnits = mkOption {
        type = listOf nonEmptyStr;
        default = [ ];
        apply = unique;
        description = "Systemd units whose structured error-level logs are counted by the central RepeatedServiceErrors rule.";
      };
      inactiveAlertUnits = mkOption {
        type = listOf nonEmptyStr;
        default = [ ];
        apply = unique;
        description = "Long-running systemd units expected to remain active. Adds them to node exporter collection and the per-host SystemdUnitInactive alert inventory.";
      };
      metricRules = mkOption {
        type = attrsOf (listOf ruleType);
        default = { };
        description = "Rules explicitly registered on the central host, grouped by owner.";
      };
      logRules = mkOption {
        type = attrsOf (listOf logRuleType);
        default = { };
        description = "LogsQL rules explicitly registered on the central host.";
      };
    };

    mkObservabilityServices = mkOption {
      type = attrsOf (submodule {
        options = {
          units = mkOption {
            type = listOf str;
            default = [ ];
          };
          metrics = mkOption {
            type = nullOr endpointType;
            default = null;
          };
          probes = mkOption {
            type = attrsOf (submodule {
              options = {
                url = mkOption { type = str; };
                module = mkOption {
                  type = enum (attrNames probeModules);
                  default = "http_2xx";
                };
                checkIPv4 = mkOption {
                  type = bool;
                  default = true;
                  description = "Check IPv4 independently, without falling back to IPv6.";
                };
                checkIPv6 = mkOption {
                  type = bool;
                  default = true;
                  description = "Check IPv6 independently, without falling back to IPv4. Disable for IPv4-only targets or probing hosts.";
                };
                interval = mkOption {
                  type = str;
                  default = "30s";
                };
                labels = mkOption {
                  type = attrsOf str;
                  default = { };
                };
              };
            });
            default = { };
          };
          metricAlerts = mkOption {
            type = listOf ruleType;
            default = [ ];
          };
          logAlerts = mkOption {
            type = listOf logRuleType;
            default = [ ];
          };
        };
      });
      default = { };
      description = "Per-service observability declarations for this host.";
    };
  };

  config = mkIf cfg.enable {
    mkObservability.inactiveAlertUnits = [
      config.systemd.services.vmagent.name
      config.systemd.services.vlagent.name
      config.systemd.services.systemd-journal-upload.name
    ];

    services.prometheus.exporters.node = {
      enable = true;
      listenAddress = loopback;
      enabledCollectors = [
        "systemd"
        "processes"
        "tcpstat"
        "interrupts"
        "textfile"
        "zfs"
      ];
      extraFlags = [
        "--collector.systemd.enable-start-time-metrics"
        "--collector.textfile.directory=${expectationMetrics}"
      ]
      ++ optionals (monitoredUnits != [ ]) (
        singleton "--collector.systemd.unit-include=^(${concatStringsSep "|" (map escapeRegex monitoredUnits)})$"
      );
    };

    services.prometheus.exporters.blackbox = mkIf (probes != { }) {
      enable = true;
      listenAddress = loopback;
      configFile = (pkgs.formats.yaml { }).generate "blackbox.yaml" {
        modules = blackboxModules;
      };
    };

    services.prometheus.exporters.postgres = mkIf config.services.postgresql.enable {
      enable = true;
      listenAddress = loopback;
      runAsLocalSuperUser = true;
      extraFlags = [
        "--collector.postmaster"
        "--collector.stat_checkpointer"
      ];
    };

    services.prometheus.exporters.smartctl = mkIf (!config.isVirtual) {
      enable = true;
      listenAddress = loopback;
    };

    mkObservability.hostMetrics = {
      node.url = "http://${loopback}:${toString config.services.prometheus.exporters.node.port}/metrics";

      blackbox = mkIf (probes != { }) {
        url = "http://${loopback}:${toString config.services.prometheus.exporters.blackbox.port}/metrics";
      };
    };

    services.vmagent = {
      enable = true;
      remoteWrite = {
        url = if cfg.central then "http://${loopback}:8428/api/v1/write" else remoteMetricsUrl;
        basicAuthUsername = mkIf (!cfg.central) "anubis-metrics";
        basicAuthPasswordFile = mkIf (
          !cfg.central
        ) config.sops.secrets.observability_metrics_ingest_password.path;
      };
      prometheusConfig = {
        global = {
          scrape_interval = "30s";
          external_labels = {
            inherit host;
            environment = cfg.environment;
          };
        };
        scrape_configs = scrapeJobs ++ probeJobs;
      };
      extraArgs = [
        "-enableTCP6"
        "-httpListenAddr=${loopback}:8429"
        "-remoteWrite.maxDiskUsagePerURL=1GiB"
      ];
    };

    networking.hosts = mkIf (!cfg.central) {
      ${config.tailscaleAddresses.osiris.ipv4} = [
        "metrics-ingest.${config.privateDomain}"
        "logs-ingest.${config.privateDomain}"
      ];
    };

    services.journald.upload = {
      enable = true;
      # journal-upload keeps the structured journal format; local vlagent
      # handles disk-backed retries when the central VictoriaLogs is offline.
      settings.Upload.URL = "http://${loopback}:9429/insert/journald";
    };

    services.vlagent = {
      enable = true;
      remoteWrite = {
        url = if cfg.central then "http://${loopback}:9428/insert/native" else remoteLogsUrl;
        maxDiskUsagePerUrl = "1GiB";
        basicAuthUsername = mkIf (!cfg.central) "anubis-logs";
        basicAuthPasswordFile = mkIf (
          !cfg.central
        ) config.sops.secrets.observability_logs_ingest_password.path;
      };
      extraArgs = singleton "-httpListenAddr=${loopback}:9429";
    };

    # Basic Auth and the remote-write buffer are provided by the native
    # module; the queue must survive a restart and stay bounded.
    systemd.services.vmagent.serviceConfig.CacheDirectory = "vmagent";

    services.journald.extraConfig = /* ini */ ''
      SystemMaxUse=2G
      SystemKeepFree=2G
    '';

    sops.secrets = mkIf (!cfg.central) {
      observability_metrics_ingest_password = {
        key = "observability/metrics_ingest_password";
        restartUnits = singleton "vmagent.service";
        sopsFile = "${inputs.my-secrets}/common/secrets.yaml";
      };
      observability_logs_ingest_password = {
        key = "observability/logs_ingest_password";
        restartUnits = singleton "vlagent.service";
        sopsFile = "${inputs.my-secrets}/common/secrets.yaml";
      };
    };

    assertions =
      mapAttrsToList (
        name:
        { metricAlerts, logAlerts, ... }:
        {
          assertion = all ({ labels, ... }: labels ? severity) (metricAlerts ++ logAlerts);
          message = "mkObservabilityServices.${name}: every alert needs a severity label";
        }
      ) services
      ++ mapAttrsToList (
        name:
        { checkIPv4, checkIPv6, ... }:
        {
          assertion = checkIPv4 || checkIPv6;
          message = "mkObservabilityServices probe ${name}: at least one of checkIPv4 and checkIPv6 must be enabled";
        }
      ) probes;
  };
}
