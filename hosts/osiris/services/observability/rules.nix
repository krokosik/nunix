{ ... }:
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
      ];
    services = [
      {
        alert = "HttpProbeFailed";
        expr = ''probe_success{job=~"probe/.*"} == 0'';
        for = "2m";
        labels.severity = "critical";
        annotations.summary = "Public check for {{ $labels.service }} failed on {{ $labels.host }}";
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
