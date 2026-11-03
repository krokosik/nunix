{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib.lists) singleton;
  inherit (lib.meta) getExe';
  inherit (lib.modules) mkAfter mkIf;
  inherit (lib.strings) escapeShellArg;
  backupDir = config.services.postgresqlBackup.location;
  backupMount = config.fileSystems."/var/backup/postgresql".device;
  metricsDirectory = "/var/lib/${config.systemd.services.postgresqlBackup.serviceConfig.StateDirectory}";
in
{
  # Back up the entire cluster, including roles and databases provisioned by
  # other services. The live PostgreSQL data directory remains on rpool.
  services.postgresqlBackup = {
    enable = true;
    location = "/var/backup/postgresql";
    compression = "zstd";
    startAt = "*-*-* 01:15:00";
  };

  systemd.services.postgresqlBackup = {
    unitConfig.RequiresMountsFor = singleton backupDir;
    serviceConfig.ExecStartPre = pkgs.writeShellScript "check-postgresql-backup-mount" /* bash */ ''
      if [ "$(${getExe' pkgs.util-linux "findmnt"} --noheadings --output SOURCE --target ${escapeShellArg backupDir})" != ${escapeShellArg backupMount} ]; then
        echo "Refusing PostgreSQL backup: ${backupDir} is not mounted from ${backupMount}" >&2
        exit 1
      fi
    '';

    serviceConfig = {
      StateDirectory = mkIf config.mkObservability.enable "postgresql-backup-metrics";
      StateDirectoryMode = mkIf config.mkObservability.enable "0755";
    };

    # ExecStartPost runs only after the native backup script successfully
    # renames the completed dump. Publish atomically and retain across boots.
    postStart = mkIf config.mkObservability.enable (mkAfter /* bash */ ''
      set -euo pipefail
      temporary="$(${getExe' pkgs.coreutils "mktemp"} --tmpdir="$STATE_DIRECTORY" .backup.XXXXXXXX)"
      trap '${getExe' pkgs.coreutils "rm"} --force "$temporary"' EXIT
      printf '# HELP postgresql_backup_last_success_timestamp_seconds Last successful cluster backup.\n# TYPE postgresql_backup_last_success_timestamp_seconds gauge\npostgresql_backup_last_success_timestamp_seconds{backup="cluster"} %s\n' \
        "$(${getExe' pkgs.coreutils "date"} +%s)" > "$temporary"
      ${getExe' pkgs.coreutils "chmod"} 0644 "$temporary"
      ${getExe' pkgs.coreutils "mv"} --force "$temporary" "$STATE_DIRECTORY/backup.prom"
    '');
  };

  # Create the directory before the first scheduled backup. The exporter can
  # read only the timestamp; database dumps retain their private permissions.
  systemd.tmpfiles.rules = mkIf config.mkObservability.enable (
    singleton "d ${metricsDirectory} 0755 postgres postgres - -"
  );

  services.prometheus.exporters.node.extraFlags = mkIf config.mkObservability.enable (
    singleton "--collector.textfile.directory=${metricsDirectory}"
  );
}
