{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib.attrsets)
    attrNames
    listToAttrs
    mapAttrs'
    mapAttrsToList
    nameValuePair
    ;
  inherit (lib.lists) concatMap optional singleton;
  inherit (lib.meta) getExe getExe';
  inherit (lib.modules) mkForce mkIf mkMerge;
  inherit (lib.options) mkOption;
  inherit (lib.strings) escapeShellArg escapeShellArgs optionalString;
  inherit (lib.types)
    attrsOf
    bool
    listOf
    str
    submodule
    ;
  rpc_port = 3901;
  buckets = config.mkGarageBucket;
in
{
  options.mkGarageBucket = mkOption {
    default = { };
    description = ''
      Garage buckets with service-specific SOPS credentials. The helper
      provisions each bucket and access key, applies its permissions, and
      orders the provisioning unit before every consumer service.
    '';
    type = attrsOf (
      let
        outerConfig = config;
      in
      submodule (
        { name, config, ... }:
        {
          options = {
            bucketName = mkOption {
              type = str;
              default = name;
              description = "Garage bucket name. Defaults to the attribute name.";
            };
            credentialOwner = mkOption {
              type = str;
              default = name;
              description = "System user that reads this bucket's SOPS credentials.";
            };
            consumerService = mkOption {
              type = listOf str;
              default = singleton "${name}.service";
              description = ''
                Systemd units that consume this bucket and must wait for
                Garage provisioning to complete.
              '';
            };
            accessKeySecretName = mkOption {
              type = str;
              default = "${name}/s3_access_key";
              description = "SOPS secret name containing the Garage access key.";
            };
            secretKeySecretName = mkOption {
              type = str;
              default = "${name}/s3_secret_key";
              description = "SOPS secret name containing the Garage secret key.";
            };
            accessKeyFile = mkOption {
              type = str;
              readOnly = true;
              description = "Decrypted Garage access key path.";
            };
            secretKeyFile = mkOption {
              type = str;
              readOnly = true;
              description = "Decrypted Garage secret key path.";
            };
            permissions = {
              read = mkOption {
                type = bool;
                default = true;
                description = "Grant read access to the bucket.";
              };
              write = mkOption {
                type = bool;
                default = true;
                description = "Grant write access to the bucket.";
              };
              owner = mkOption {
                type = bool;
                default = false;
                description = "Grant bucket administrative access.";
              };
            };
          };

          config = {
            accessKeyFile = outerConfig.sops.secrets.${config.accessKeySecretName}.path;
            secretKeyFile = outerConfig.sops.secrets.${config.secretKeySecretName}.path;
          };
        }
      )
    );
  };

  config = mkMerge [
    {
      users = {
        groups.garage = { };
        users.garage = {
          isSystemUser = true;
          group = "garage";
        };
      };

      sops = {
        secrets = {
          garage_rpc_secret = {
            key = "garage/rpc_secret";
            owner = "garage";
            restartUnits = singleton "garage.service";
          };
          garage_default_access_key.key = "garage/default_access_key";
          garage_default_secret_key.key = "garage/default_secret_key";
        };

        templates."garage-default.env" = {
          content = /* bash */ ''
            GARAGE_DEFAULT_ACCESS_KEY=${config.sops.placeholder.garage_default_access_key}
            GARAGE_DEFAULT_SECRET_KEY=${config.sops.placeholder.garage_default_secret_key}
            GARAGE_DEFAULT_BUCKET=default
          '';
          restartUnits = singleton "garage.service";
        };
      };

      services.garage = {
        enable = true;
        # for garage, package must be explicit
        package = pkgs.garage_2;
        environmentFile = config.sops.templates."garage-default.env".path;
        settings = {
          metadata_dir = "/var/lib/garage/meta";
          data_dir = "/var/lib/garage/data";
          db_engine = "sqlite";
          replication_factor = 1;
          rpc_secret_file = config.sops.secrets.garage_rpc_secret.path;

          rpc_bind_addr = "127.0.0.1:${toString rpc_port}";
          rpc_public_addr = "127.0.0.1:${toString rpc_port}";

          admin = {
            api_bind_addr = "127.0.0.1:3903";
            metrics_require_token = false;
          };

          s3_api = {
            api_bind_addr = "127.0.0.1:${toString config.mkTraefikServices.garage.port}";
            s3_region = "garage";
          };
        };
      };

      mkTraefikServices.garage = {
        port = 3900;
        chain = singleton "chain-tailscale";
      };

      mkObservabilityServices.garage = {
        units = singleton "garage.service";
        metrics.url = "http://${config.services.garage.settings.admin.api_bind_addr}/metrics";
      };

      mkObservability.inactiveAlertUnits = mkIf config.services.garage.enable config.mkObservabilityServices.garage.units;
    }

    (mkIf (buckets != { }) {
      assertions = mapAttrsToList (name: bucket: {
        assertion = bucket.permissions.read || bucket.permissions.write || bucket.permissions.owner;
        message = "mkGarageBucket.${name} must grant at least one permission";
      }) buckets;

      sops.secrets = listToAttrs (
        concatMap (
          name:
          let
            bucket = buckets.${name};
            restartUnits = singleton "${name}-garage-bucket.service" ++ bucket.consumerService;
          in
          [
            {
              name = bucket.accessKeySecretName;
              value = {
                owner = bucket.credentialOwner;
                inherit restartUnits;
              };
            }
            {
              name = bucket.secretKeySecretName;
              value = {
                owner = bucket.credentialOwner;
                inherit restartUnits;
              };
            }
          ]
        ) (attrNames buckets)
      );

      systemd.services =
        mapAttrs' (
          name: bucket:
          let
            permissionArgs =
              optional bucket.permissions.read "--read"
              ++ optional bucket.permissions.write "--write"
              ++ optional bucket.permissions.owner "--owner";
            deniedPermissionArgs =
              optional (!bucket.permissions.read) "--read"
              ++ optional (!bucket.permissions.write) "--write"
              ++ optional (!bucket.permissions.owner) "--owner";
          in
          nameValuePair "${name}-garage-bucket" {
            description = "Provision the ${bucket.bucketName} Garage bucket and access key";
            after = singleton "garage.service";
            requires = singleton "garage.service";
            wants = singleton "sops-install-secrets.service";
            requiredBy = bucket.consumerService;
            before = bucket.consumerService;
            unitConfig.ConditionPathExists = [
              bucket.accessKeyFile
              bucket.secretKeyFile
            ];
            serviceConfig = {
              Type = "oneshot";
              RemainAfterExit = true;
              LoadCredential = [
                "s3_access_key:${bucket.accessKeyFile}"
                "s3_secret_key:${bucket.secretKeyFile}"
              ];
            };
            script = /* bash */ ''
              set -euo pipefail

              if [ ! -s "$CREDENTIALS_DIRECTORY/s3_access_key" ] || [ ! -s "$CREDENTIALS_DIRECTORY/s3_secret_key" ]; then
                echo "ERROR: Garage credentials for ${name} are empty" >&2
                exit 1
              fi

              access_key="$(<"$CREDENTIALS_DIRECTORY/s3_access_key")"
              secret_key="$(<"$CREDENTIALS_DIRECTORY/s3_secret_key")"
              garage=${getExe config.services.garage.package}

              for _ in {1..60}; do
                if "$garage" status > /dev/null 2>&1; then
                  break
                fi

                ${getExe' pkgs.coreutils "sleep"} 1
              done

              if ! "$garage" status > /dev/null 2>&1; then
                echo "ERROR: Garage did not become ready within 60 seconds" >&2
                exit 1
              fi

              if ! "$garage" key info "$access_key" > /dev/null 2>&1; then
                "$garage" key import --yes "$access_key" "$secret_key"
              fi

              if ! "$garage" bucket info ${escapeShellArg bucket.bucketName} > /dev/null 2>&1; then
                "$garage" bucket create ${escapeShellArg bucket.bucketName}
              fi

              "$garage" bucket allow ${escapeShellArgs permissionArgs} ${escapeShellArg bucket.bucketName} --key "$access_key"
              ${optionalString (deniedPermissionArgs != [ ]) /* bash */ ''
                "$garage" bucket deny ${escapeShellArgs deniedPermissionArgs} ${escapeShellArg bucket.bucketName} --key "$access_key"
              ''}
            '';
          }
        ) buckets
        // {
          garage.serviceConfig = {
            DynamicUser = mkForce false;
            User = "garage";
            Group = "garage";
            ExecStart = mkForce /* bash */ ''
              ${getExe pkgs.garage_2} server --single-node --default-bucket
            '';
          };
        };
    })
  ];
}
