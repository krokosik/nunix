{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
let
  cfg = config.mkObservability;
  services = config.mkObservabilityServices;
  host = config.networking.hostName;
  loopback = "127.0.0.1";
  inherit (lib.lists) singleton;

  ruleType = lib.types.submodule {
    options = {
      alert = lib.mkOption { type = lib.types.nonEmptyStr; };
      expr = lib.mkOption { type = lib.types.nonEmptyStr; };
      for = lib.mkOption {
        type = lib.types.str;
        default = "0s";
      };
      labels = lib.mkOption {
        type = lib.types.attrsOf lib.types.str;
        default = { };
      };
      annotations = lib.mkOption {
        type = lib.types.attrsOf lib.types.str;
        default = { };
      };
    };
  };

  endpointType = lib.types.submodule {
    options = {
      url = lib.mkOption { type = lib.types.str; };
      interval = lib.mkOption {
        type = lib.types.str;
        default = "30s";
      };
      labels = lib.mkOption {
        type = lib.types.attrsOf lib.types.str;
        default = { };
      };
    };
  };

  logRuleType = lib.types.submodule {
    options = {
      alert = lib.mkOption { type = lib.types.nonEmptyStr; };
      expr = lib.mkOption { type = lib.types.nonEmptyStr; };
      interval = lib.mkOption {
        type = lib.types.str;
        default = "5m";
      };
      for = lib.mkOption {
        type = lib.types.str;
        default = "0s";
      };
      labels = lib.mkOption {
        type = lib.types.attrsOf lib.types.str;
        default = { };
      };
      annotations = lib.mkOption {
        type = lib.types.attrsOf lib.types.str;
        default = { };
      };
    };
  };

  localTargets = lib.mapAttrs' (
    name: endpoint: lib.nameValuePair "host/${name}" endpoint
  ) cfg.hostMetrics;
  serviceTargets = lib.concatMapAttrs (
    name: service:
    lib.optionalAttrs (service.metrics != null) {
      "service/${name}" = service.metrics;
    }
  ) services;
  postgresTarget = lib.optionalAttrs (config.services.postgresql.enable && cfg.enable) {
    "host/postgres" = {
      url = "http://${loopback}:${toString config.services.prometheus.exporters.postgres.port}/metrics";
      interval = "30s";
      labels = { };
    };
  };
  smartTarget = lib.optionalAttrs (!config.isVirtual && cfg.enable) {
    "host/smartctl" = {
      url = "http://${loopback}:${toString config.services.prometheus.exporters.smartctl.port}/metrics";
      interval = "60s";
      labels = { };
    };
  };
  # Agents see declarations from this host only. Nothing here evaluates or
  # imports another nixosConfiguration to discover its services.
  scrapeTargets = localTargets // serviceTargets // postgresTarget // smartTarget;

  scrapeJobs = lib.mapAttrsToList (
    name: endpoint:
    let
      parsed = lib.match "(https?)://([^/]+)(/.*)?" endpoint.url;
      scheme = lib.elemAt parsed 0;
      address = lib.elemAt parsed 1;
      path = lib.elemAt parsed 2;
    in
    {
      job_name = name;
      inherit scheme;
      metrics_path = if path == null then "/metrics" else path;
      scrape_interval = endpoint.interval;
      static_configs = singleton {
        targets = singleton address;
        labels = endpoint.labels // {
          service = lib.lists.last (lib.splitString "/" name);
        };
      };
    }
  ) scrapeTargets;

  probes = lib.concatMapAttrs (
    name: service:
    lib.mapAttrs' (probeName: probe: lib.nameValuePair "${name}/${probeName}" probe) service.probes
  ) services;
  probeFamilies = probe: lib.optional probe.checkIPv4 "4" ++ lib.optional probe.checkIPv6 "6";
  probeJobs = lib.concatLists (
    lib.mapAttrsToList (
      name: probe:
      map (family: {
        job_name = "probe/${name}/ip${family}";
        metrics_path = "/probe";
        scrape_interval = probe.interval;
        params.module = singleton "${probe.module}_ip${family}";
        static_configs = singleton {
          targets = singleton probe.url;
          labels = probe.labels // {
            service = lib.lists.head (lib.splitString "/" name);
            check = lib.lists.last (lib.splitString "/" name);
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
  blackboxModules = lib.concatMapAttrs (
    name: module:
    lib.listToAttrs (
      map
        (
          family:
          lib.nameValuePair "${name}_ip${family}" (
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
  monitoredUnits = lib.unique (
    cfg.monitoredUnits ++ lib.concatMap (svc: svc.units) (lib.attrValues services)
  );
  writableFilesystems = lib.filterAttrs (
    _: fs:
    lib.elem fs.fsType [
      "zfs"
      "ext4"
      "ext3"
      "ext2"
      "xfs"
      "btrfs"
      "vfat"
      "f2fs"
    ]
    && !lib.elem "ro" fs.options
  ) config.fileSystems;
  expectedPools = lib.unique (
    config.boot.zfs.extraPools
    ++ map ({ device, ... }: lib.lists.head (lib.splitString "/" device)) (
      lib.attrValues (lib.filterAttrs (_: fs: fs.fsType == "zfs") config.fileSystems)
    )
  );
  # These declarations travel with each host's metrics, without evaluating
  # another host or maintaining a second inventory in the central rules.
  expectationMetrics = pkgs.writeTextDir "expectations.prom" (
    /* prometheus */ ''
      # HELP node_expected_filesystem_writable Configured persistent writable mountpoint.
      # TYPE node_expected_filesystem_writable gauge
    ''
    + lib.concatMapStrings (mountpoint: /* prometheus */ ''
      node_expected_filesystem_writable{mountpoint=${lib.strings.toJSON mountpoint}} 1
    '') (lib.attrNames writableFilesystems)
    + /* prometheus */ ''
      # HELP node_expected_zfs_pool Configured ZFS pool.
      # TYPE node_expected_zfs_pool gauge
    ''
    + lib.concatMapStrings (pool: /* prometheus */ ''
      node_expected_zfs_pool{zpool=${lib.strings.toJSON pool}} 1
    '') expectedPools
  );
  remoteMetricsUrl = "https://metrics-ingest.${config.privateDomain}/api/v1/write";
  remoteLogsUrl = "https://logs-ingest.${config.privateDomain}/insert/native";
in
{
  options = {
    mkObservability = {
      enable = lib.mkEnableOption "host-local metrics and journal forwarding";
      environment = lib.mkOption {
        type = lib.types.str;
        default = "home";
      };
      central = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Run the Victoria stores and centralized alerting on this host.";
      };
      hostMetrics = lib.mkOption {
        type = lib.types.attrsOf endpointType;
        default = { };
        description = "Host-level exporter and infrastructure scrape endpoints.";
      };
      monitoredUnits = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = "Host infrastructure units tracked by the node exporter.";
      };
      metricRules = lib.mkOption {
        type = lib.types.attrsOf (lib.types.listOf ruleType);
        default = { };
        description = "Rules explicitly registered on the central host, grouped by owner.";
      };
      logRules = lib.mkOption {
        type = lib.types.attrsOf (lib.types.listOf logRuleType);
        default = { };
        description = "LogsQL rules explicitly registered on the central host.";
      };
    };

    mkObservabilityServices = lib.mkOption {
      type = lib.types.attrsOf (
        lib.types.submodule {
          options = {
            units = lib.mkOption {
              type = lib.types.listOf lib.types.str;
              default = [ ];
            };
            metrics = lib.mkOption {
              type = lib.types.nullOr endpointType;
              default = null;
            };
            probes = lib.mkOption {
              type = lib.types.attrsOf (
                lib.types.submodule {
                  options = {
                    url = lib.mkOption { type = lib.types.str; };
                    module = lib.mkOption {
                      type = lib.types.enum (lib.attrNames probeModules);
                      default = "http_2xx";
                    };
                    checkIPv4 = lib.mkOption {
                      type = lib.types.bool;
                      default = true;
                      description = "Check IPv4 independently, without falling back to IPv6.";
                    };
                    checkIPv6 = lib.mkOption {
                      type = lib.types.bool;
                      default = true;
                      description = "Check IPv6 independently, without falling back to IPv4. Disable for IPv4-only targets or probing hosts.";
                    };
                    interval = lib.mkOption {
                      type = lib.types.str;
                      default = "30s";
                    };
                    labels = lib.mkOption {
                      type = lib.types.attrsOf lib.types.str;
                      default = { };
                    };
                  };
                }
              );
              default = { };
            };
            metricAlerts = lib.mkOption {
              type = lib.types.listOf ruleType;
              default = [ ];
            };
            logAlerts = lib.mkOption {
              type = lib.types.listOf logRuleType;
              default = [ ];
            };
          };
        }
      );
      default = { };
      description = "Per-service observability declarations for this host.";
    };
  };

  config = lib.mkIf cfg.enable {
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
      ++ lib.optionals (monitoredUnits != [ ]) [
        "--collector.systemd.unit-include=^(${lib.concatStringsSep "|" (map lib.escapeRegex monitoredUnits)})$"
      ];
    };

    services.prometheus.exporters.blackbox = lib.mkIf (probes != { }) {
      enable = true;
      listenAddress = loopback;
      configFile = (pkgs.formats.yaml { }).generate "blackbox.yaml" {
        modules = blackboxModules;
      };
    };

    services.prometheus.exporters.postgres = lib.mkIf config.services.postgresql.enable {
      enable = true;
      listenAddress = loopback;
      runAsLocalSuperUser = true;
      extraFlags = [
        "--collector.postmaster"
        "--collector.stat_checkpointer"
      ];
    };

    services.prometheus.exporters.smartctl = lib.mkIf (!config.isVirtual) {
      enable = true;
      listenAddress = loopback;
    };

    mkObservability.hostMetrics.node.url = "http://${loopback}:${toString config.services.prometheus.exporters.node.port}/metrics";
    mkObservability.hostMetrics.blackbox = lib.mkIf (probes != { }) {
      url = "http://${loopback}:${toString config.services.prometheus.exporters.blackbox.port}/metrics";
    };

    services.vmagent = {
      enable = true;
      remoteWrite = {
        url = if cfg.central then "http://${loopback}:8428/api/v1/write" else remoteMetricsUrl;
        basicAuthUsername = lib.mkIf (!cfg.central) "anubis-metrics";
        basicAuthPasswordFile = lib.mkIf (
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

    networking.hosts = lib.mkIf (!cfg.central) {
      ${config.homeserverPrivateIp} = [
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
        basicAuthUsername = lib.mkIf (!cfg.central) "anubis-logs";
        basicAuthPasswordFile = lib.mkIf (
          !cfg.central
        ) config.sops.secrets.observability_logs_ingest_password.path;
      };
      extraArgs = [ "-httpListenAddr=${loopback}:9429" ];
    };

    # Basic Auth and the remote-write buffer are provided by the native
    # module; the queue must survive a restart and stay bounded.
    systemd.services.vmagent.serviceConfig.CacheDirectory = "vmagent";

    services.journald.extraConfig = /* ini */ ''
      SystemMaxUse=2G
      SystemKeepFree=2G
    '';

    sops.secrets = lib.mkIf (!cfg.central) {
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
      lib.mapAttrsToList (name: svc: {
        assertion = lib.all (rule: rule.labels ? severity) (svc.metricAlerts ++ svc.logAlerts);
        message = "mkObservabilityServices.${name}: every alert needs a severity label";
      }) services
      ++ lib.mapAttrsToList (name: probe: {
        assertion = probe.checkIPv4 || probe.checkIPv6;
        message = "mkObservabilityServices probe ${name}: at least one of checkIPv4 and checkIPv6 must be enabled";
      }) probes;
  };
}
