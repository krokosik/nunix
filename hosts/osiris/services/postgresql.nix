{
  config,
  pkgs,
  lib,
  ...
}:
let
  inherit (lib.attrsets) mapAttrs' mapAttrsToList nameValuePair;
  inherit (lib.lists) map singleton;
  inherit (lib.modules) mkIf mkMerge mkOverride;
  inherit (lib.options) mkOption;
  inherit (lib.strings) concatStringsSep replaceStrings;
  inherit (lib.types)
    attrsOf
    listOf
    str
    submodule
    ;
  svcs = config.mkPostgresServices;
in
{
  options.mkPostgresServices = mkOption {
    default = { };
    description = ''
      svcs that consume the shared native postgres instance with a
      sops-managed password. The helper provisions the db + role +
      rotation oneshot; the svc module is responsible for plumbing
      the password into its own env file and pointing the upstream
      service at host.containers.internal:5432.
    '';
    type = attrsOf (
      submodule (
        { name, ... }:
        {
          options = {
            dbName = mkOption {
              type = str;
              default = replaceStrings (singleton "-") (singleton "_") name;
              description = ''
                Postgres database (and role) name. Defaults to the
                attribute name with hyphens replaced by underscores
                (paperless-ngx → paperless_ngx) so the role name is
                a valid SQL identifier.
              '';
            };
            consumerService = mkOption {
              type = listOf str;
              default = singleton "${config.virtualisation.oci-containers.backend}-${name}.service";
              description = ''
                Systemd units that consume this role and must wait
                for the password rotation oneshot to complete. The
                oneshot is wired with `before` and `wantedBy` on
                every listed unit, so no consumer ever starts with
                a stale password. Pass every unit that opens a
                connection (e.g. paperless-ngx with
                paperless-{web,scheduler,task-queue,consumer})
                rather than trusting transitive ordering through a
                single representative unit.
              '';
            };
            secretName = mkOption {
              type = str;
              default = "${name}/db_password";
              description = ''
                sops secret name for the role's password. Defaults
                to "<name>/db_password". Override only if the
                secret already exists under a non-standard name.
              '';
            };
            extraCommands = mkOption {
              type = listOf str;
              default = [ ];
              description = ''
                Extra SQL commands to run as the postgres superuser
                after the role and database are created. Useful for
                per-database extensions (e.g. pg_cron) or granting
                privileges to other roles.
              '';
            };
          };
        }
      )
    );
  };

  config = mkMerge [
    {
      mkObservability.inactiveAlertUnits = mkIf config.services.postgresql.enable (
        singleton config.systemd.services.postgresql.name
      );

      services.postgresql = {
        enable = true;
        package = pkgs.postgresql_17;
        enableTCPIP = true;

        # Peer auth for native services on the Unix socket; scram for TCP.
        # Container svcs connect from the default docker bridge.
        authentication = mkOverride 10 ''
          local all all                peer
          host  all all 127.0.0.1/32   scram-sha-256
          host  all all ::1/128        scram-sha-256
          host  all all 172.16.0.0/12  scram-sha-256
        '';
      };
    }

    (mkIf (svcs != { }) {
      sops.secrets = mapAttrs' (
        name:
        { secretName, ... }:
        nameValuePair secretName {
          owner = "postgres";
          restartUnits = singleton "${name}-db-password.service";
        }
      ) svcs;

      services.postgresql = {
        ensureDatabases = mapAttrsToList (_: { dbName, ... }: dbName) svcs;
        ensureUsers = mapAttrsToList (
          _:
          { dbName, ... }:
          {
            name = dbName;
            ensureDBOwnership = true;
          }
        ) svcs;
      };

      systemd.services = mapAttrs' (
        name: svc:
        let
          secretPath = config.sops.secrets.${svc.secretName}.path;
        in
        nameValuePair "${name}-db-password" {
          description = "Set ${name} postgres role password from sops secret";
          after = [
            "postgresql.service"
            "postgresql-setup.service"
          ];
          requires = singleton "postgresql.service";
          wants = [
            "postgresql-setup.service"
            "sops-install-secrets.service"
          ];
          wantedBy = svc.consumerService;
          before = svc.consumerService;
          # Skip the unit if sops hasn't decrypted *this specific*
          # secret yet (sops-install-secrets.service may report
          # success overall while a single entry failed — wrong age
          # key on file, blob shape changed upstream, etc.). Without
          # this guard the script below would cat a missing file,
          # send an empty password to ALTER USER, and silently lock
          # the svc out of its DB.
          unitConfig.ConditionPathExists = secretPath;
          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
            User = "postgres";
            Group = "postgres";
          };
          script =
            /* bash */ ''
              set -euo pipefail
              if [ ! -s "${secretPath}" ]; then
                echo "ERROR: sops secret ${secretPath} is empty — refusing to clear ${svc.dbName} postgres password" >&2
                exit 1
              fi
              ${config.services.postgresql.package}/bin/psql -tAc \
                "ALTER USER ${svc.dbName} WITH PASSWORD '$(cat ${secretPath})'"
            ''
            + (concatStringsSep "\n" (
              map (
                cmd:
                "${config.services.postgresql.package}/bin/psql --dbname=${svc.dbName} --tuples-only --no-align --command=\"${cmd}\""
              ) svc.extraCommands
            ));
        }
      ) svcs;
    })
  ];
}
