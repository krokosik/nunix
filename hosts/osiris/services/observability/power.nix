{
  config,
  lib,
  ...
}:
let
  inherit (lib.lists) singleton;
in
{
  # Load the counters before systemd-tmpfiles applies their read permissions.
  boot.kernelModules = singleton "intel_rapl_msr";

  # Diagnostics are run explicitly by an administrator; no polling daemon or
  # unrestricted access to CPU MSRs is needed for node exporter.
  environment.systemPackages = with config.boot.kernelPackages; [ turbostat ];

  # /sys/class/powercap exposes package and child zones as separate symlinks.
  # Match MMIO zones too: the collector visits every available RAPL interface.
  # Only energy counters become group-readable; power limits stay root-only.
  systemd = {
    services.systemd-tmpfiles-setup.after = singleton "systemd-modules-load.service";

    tmpfiles.settings.osiris-rapl = {
      "/sys/class/powercap/intel-rapl*/energy_uj".z = {
        mode = "0440";
        user = "root";
        group = config.services.prometheus.exporters.node.group;
      };
    };
  };
}
