{ config, ... }:
{
  mkObservability.metricRules = {
    hosts =
      map
        (host: {
          alert = "HostDown";
          expr = ''absent_over_time(up{job="host/node",host="${host}"}[5m])'';
          for = "2m";
          labels.severity = "critical";
          annotations.summary = "${host} stopped reporting";
        })
        [
          "osiris"
          "anubis"
        ]
      ++ [
        {
          alert = "SystemdUnitFailed";
          expr = ''node_systemd_unit_state{state="failed"} == 1'';
          for = "2m";
          labels.severity = "critical";
          annotations.summary = "{{ $labels.name }} failed on {{ $labels.host }}";
        }
        {
          alert = "FilesystemAlmostFull";
          expr = ''node_filesystem_avail_bytes{fstype!~"tmpfs|overlay|devtmpfs|squashfs"} / node_filesystem_size_bytes{fstype!~"tmpfs|overlay|devtmpfs|squashfs"} < 0.15'';
          for = "10m";
          labels.severity = "warning";
          annotations.summary = "Filesystem {{ $labels.mountpoint }} on {{ $labels.host }} almost full";
        }
        {
          alert = "HostOomKill";
          expr = ''increase(node_vmstat_oom_kill{job="host/node"}[10m]) > 0'';
          labels.severity = "warning";
          annotations.summary = "Kernel killed a process due to insufficient memory on {{ $labels.host }}";
        }
      ];

    filesystems = [
      {
        alert = "FilesystemCriticallyFull";
        expr = /* promql */ ''
          (
            node_filesystem_avail_bytes{job="host/node"}
            / node_filesystem_size_bytes{job="host/node"} < 0.05
          )
          and on (host, environment, instance, mountpoint)
            node_expected_filesystem_writable{job="host/node"}
          and on (host, environment, instance, device, mountpoint)
            (node_filesystem_readonly{job="host/node"} == 0)
        '';
        for = "5m";
        labels.severity = "critical";
        annotations.summary = "Filesystem {{ $labels.mountpoint }} on {{ $labels.host }} has less than 5% available";
      }
      {
        alert = "FilesystemReadOnly";
        expr = /* promql */ ''
          (node_filesystem_readonly{job="host/node"} == 1)
          and on (host, environment, instance, mountpoint)
            node_expected_filesystem_writable{job="host/node"}
        '';
        for = "2m";
        labels.severity = "critical";
        annotations.summary = "Configured writable filesystem {{ $labels.mountpoint }} on {{ $labels.host }} is read-only";
      }
    ];

    postgresql = [
      {
        alert = "PostgresqlUnavailable";
        expr = ''pg_up{job="host/postgres"} == 0'';
        for = "2m";
        labels.severity = "critical";
        annotations.summary = "PostgreSQL is unavailable to its exporter on {{ $labels.host }}";
      }
      {
        alert = "PostgresqlConnectionsAlmostFull";
        # numbackends includes idle connections. PostgreSQL 17 reserves slots
        # for superusers and roles granted pg_use_reserved_connections.
        expr = /* promql */ ''
          sum by (host, environment, instance) (
            pg_stat_database_numbackends{job="host/postgres",datname!=""}
          )
          / on (host, environment, instance) (
            max by (host, environment, instance) (pg_settings_max_connections{job="host/postgres"})
            - max by (host, environment, instance) (pg_settings_superuser_reserved_connections{job="host/postgres"})
            - max by (host, environment, instance) (pg_settings_reserved_connections{job="host/postgres"})
          ) > 0.85
        '';
        for = "10m";
        labels.severity = "warning";
        annotations.summary = "PostgreSQL on {{ $labels.host }} uses more than 85% of non-reserved connection slots";
      }
    ];

    disks = [
      {
        alert = "SmartHealthFailed";
        expr = /* promql */ ''
          max by (host, environment, instance, device) (
            (smartctl_device_smart_status{job="host/smartctl"} == 0)
            or (smartctl_device_critical_warning{job="host/smartctl"} > 0)
          )
        '';
        for = "2m";
        labels.severity = "critical";
        annotations.summary = "Disk {{ $labels.device }} on {{ $labels.host }} reports a SMART health failure or NVMe critical warning";
      }
      {
        alert = "SmartDiskDeteriorating";
        # ATA attributes are gauges; NVMe media errors are a counter. Only
        # growth alerts on historical reallocations/media errors, not totals.
        expr = /* promql */ ''
          max by (host, environment, instance, device) (
            (smartctl_device_attribute{job="host/smartctl",attribute_id=~"197|198",attribute_value_type="raw"} > 0)
            or (delta(smartctl_device_attribute{job="host/smartctl",attribute_id="5",attribute_value_type="raw"}[24h]) > 0)
            or (increase(smartctl_device_media_errors{job="host/smartctl"}[24h]) > 0)
          )
        '';
        for = "10m";
        labels.severity = "warning";
        annotations.summary = "Disk {{ $labels.device }} on {{ $labels.host }} has pending/uncorrectable sectors or new reallocated sectors/media errors";
      }
    ];

    zfs = [
      {
        alert = "ZfsPoolUnhealthy";
        expr = ''node_zfs_zpool_state{job="host/node",state!="online"} == 1'';
        for = "2m";
        labels.severity = "critical";
        annotations.summary = "ZFS pool {{ $labels.zpool }} on {{ $labels.host }} is {{ $labels.state }}";
      }
      {
        alert = "ZfsPoolMissing";
        expr = /* promql */ ''
          (
            node_expected_zfs_pool{job="host/node"}
            unless on (host, environment, instance, zpool)
              node_zfs_zpool_state{job="host/node"}
          )
          and on (host, environment, instance) (up{job="host/node"} == 1)
        '';
        for = "5m";
        labels.severity = "critical";
        annotations.summary = "Expected ZFS pool {{ $labels.zpool }} on {{ $labels.host }} is missing from node metrics";
      }
    ];

    backups = [
      {
        alert = "PostgresqlBackupStale";
        expr = /* promql */ ''
          (time() - postgresql_backup_last_success_timestamp_seconds{job="host/node"} > 36 * 3600)
          and on (host, environment, instance) (up{job="host/node"} == 1)
        '';
        for = "15m";
        labels.severity = "warning";
        annotations.summary = "PostgreSQL backup on {{ $labels.host }} has not succeeded for more than 36 hours";
      }
      {
        alert = "PostgresqlBackupSuccessMissing";
        expr = /* promql */ ''
          (up{job="host/node",host="${config.networking.hostName}"} == 1)
          unless on (host, environment, instance)
            postgresql_backup_last_success_timestamp_seconds{job="host/node",backup="cluster"}
        '';
        for = "15m";
        labels.severity = "warning";
        annotations.summary = "PostgreSQL backup on {{ $labels.host }} has no recorded successful backup";
      }
    ];

    services = [
      {
        alert = "HttpProbeFailed";
        expr = ''probe_success{job=~"probe/.*"} == 0'';
        for = "2m";
        labels.severity = "critical";
        annotations = {
          summary = "{{ $labels.check }} IPv{{ $labels.ip_family }} check for {{ $labels.service }} failed from {{ $labels.vantage }}";
          dashboard_url = "${config.mkTraefikServices.grafana.fullHostname}/d/NEzutrbMk";
        };
      }
      {
        alert = "SystemdUnitInactive";
        expr = ''node_systemd_unit_state{state="active",name=~"(vmagent|vlagent|systemd-journal-upload|victoriametrics|victorialogs|vmalert-metrics|vmalert-logs|alertmanager|grafana|traefik|haproxy)[.]service"} == 0'';
        for = "5m";
        labels.severity = "critical";
        annotations.summary = "{{ $labels.name }} inactive on {{ $labels.host }}";
      }
      {
        alert = "ScrapeDown";
        expr = ''up{job=~"service/.*|host/.*"} == 0'';
        for = "2m";
        labels.severity = "warning";
        annotations.summary = "Metrics target {{ $labels.job }} down on {{ $labels.host }}";
      }
      {
        alert = "CertificateExpiring";
        expr = ''probe_ssl_earliest_cert_expiry{job=~"probe/.*"} - time() < 14 * 24 * 3600'';
        for = "1h";
        labels.severity = "warning";
        annotations.summary = "Certificate for {{ $labels.service }} expires within 14 days";
      }
    ];
  };

  mkObservability.logRules.platform = [
    {
      alert = "RepeatedServiceErrors";
      interval = "5m";
      expr = ''_SYSTEMD_UNIT:in("traefik.service", "authentik.service") level:in("error", "crit", "alert", "emerg") | stats by (_HOSTNAME, _SYSTEMD_UNIT) count() as errors | filter errors:>20'';
      labels.severity = "warning";
      annotations.summary = "Repeated errors from {{ $labels._SYSTEMD_UNIT }} on {{ $labels._HOSTNAME }}";
    }
  ];

}
