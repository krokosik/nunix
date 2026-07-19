{
  config,
  pkgs,
  lib,
  ...
}:
let
  svcs = config.myPostgresServices;
in
{
  options.myPostgresServices = lib.mkOption {
    default = { };
    description = ''
      svcs that consume the shared native postgres instance with a
      sops-managed password. The helper provisions the db + role +
      rotation oneshot; the svc module is responsible for plumbing
      the password into its own env file and pointing the upstream
      service at host.containers.internal:5432.
    '';
    type = lib.types.attrsOf (
      lib.types.submodule (
        { name, ... }:
        {
          options = {
            dbName = lib.mkOption {
              type = lib.types.str;
              default = lib.replaceStrings [ "-" ] [ "_" ] name;
              description = ''
                Postgres database (and role) name. Defaults to the
                attribute name with hyphens replaced by underscores
                (paperless-ngx → paperless_ngx) so the role name is
                a valid SQL identifier.
              '';
            };
            consumerService = lib.mkOption {
              type = lib.types.listOf lib.types.str;
              default = [ "${config.virtualisation.oci-containers.backend}-${name}.service" ];
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
            secretName = lib.mkOption {
              type = lib.types.str;
              default = "${name}/db_password";
              description = ''
                sops secret name for the role's password. Defaults
                to "<name>/db_password". Override only if the
                secret already exists under a non-standard name.
              '';
            };
            extraCommands = lib.mkOption {
              type = lib.types.listOf lib.types.str;
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

  config = lib.mkMerge [
    {
      services.postgresql = {
        enable = true;
        package = pkgs.postgresql_17;
        enableTCPIP = true;

        # Peer auth for native services on the Unix socket; scram for TCP.
        # Container svcs connect from the default docker bridge.
        authentication = lib.mkOverride 10 ''
          local all all                peer
          host  all all 127.0.0.1/32   scram-sha-256
          host  all all ::1/128        scram-sha-256
          host  all all 172.16.0.0/12  scram-sha-256
        '';
      };
    }

    (lib.mkIf (svcs != { }) {
      sops.secrets = lib.mapAttrs' (
        name: svc:
        lib.nameValuePair svc.secretName {
          owner = "postgres";
          restartUnits = [ "${name}-db-password.service" ];
        }
      ) svcs;

      services.postgresql = {
        ensureDatabases = lib.mapAttrsToList (_: svc: svc.dbName) svcs;
        ensureUsers = lib.mapAttrsToList (_: svc: {
          name = svc.dbName;
          ensureDBOwnership = true;
        }) svcs;
      };

      systemd.services = lib.mapAttrs' (
        name: svc:
        let
          secretPath = config.sops.secrets.${svc.secretName}.path;
        in
        lib.nameValuePair "${name}-db-password" {
          description = "Set ${name} postgres role password from sops secret";
          after = [
            "postgresql.service"
            "postgresql-setup.service"
          ];
          requires = [ "postgresql.service" ];
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
          script = ''
            set -euo pipefail
            if [ ! -s "${secretPath}" ]; then
              echo "ERROR: sops secret ${secretPath} is empty — refusing to clear ${svc.dbName} postgres password" >&2
              exit 1
            fi
            ${config.services.postgresql.package}/bin/psql -tAc \
              "ALTER USER ${svc.dbName} WITH PASSWORD '$(cat ${secretPath})'"
          ''
          + (lib.concatStringsSep "\n" (
            lib.map (
              cmd: "${config.services.postgresql.package}/bin/psql -d ${svc.dbName} -tAc \"${cmd}\""
            ) svc.extraCommands
          ));
        }
      ) svcs;
    })
  ];
}
