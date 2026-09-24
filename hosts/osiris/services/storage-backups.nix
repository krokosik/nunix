{
  config,
  lib,
  pkgs,
  ...
}:
let
  backupDir = config.services.postgresqlBackup.location;
  backupMount = config.fileSystems."/var/backup/postgresql".device;
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
    unitConfig.RequiresMountsFor = [ backupDir ];
    serviceConfig.ExecStartPre = pkgs.writeShellScript "check-postgresql-backup-mount" /* bash */ ''
      if [ "$(${lib.getExe' pkgs.util-linux "findmnt"} --noheadings --output SOURCE --target ${lib.escapeShellArg backupDir})" != ${lib.escapeShellArg backupMount} ]; then
        echo "Refusing PostgreSQL backup: ${backupDir} is not mounted from ${backupMount}" >&2
        exit 1
      fi
    '';
  };
}
