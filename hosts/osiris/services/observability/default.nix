{ config, ... }:
{
  imports = [
    ./victoriametrics.nix
    ./victorialogs.nix
    ./vmalert.nix
    ./alertmanager.nix
    ./grafana.nix
    ./ingress.nix
    ./rules.nix
  ];

  mkObservability.inactiveAlertUnits = [
    config.systemd.services.victoriametrics.name
    config.systemd.services.victorialogs.name
    config.systemd.services.vmalert-metrics.name
    config.systemd.services.vmalert-logs.name
    config.systemd.services.alertmanager.name
    config.systemd.services.grafana.name
  ];
}
