{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib.lists) singleton;
  rpc_port = 3901;
  s3_port = 3900;
  buckets = config.mkGarageBucket;
in
{
  options.mkGarageBucket = lib.mkOption {
    default = { };
    description = ''
      Garage buckets with service-specific SOPS credentials. The helper
      provisions each bucket and access key, applies its permissions, and
      orders the provisioning unit before every consumer service.
    '';
    type = lib.types.attrsOf (
      let
        outerConfig = config;
      in
      lib.types.submodule (
        { name, config, ... }:
        {
          options = {
            bucketName = lib.mkOption {
              type = lib.types.str;
              default = name;
              description = "Garage bucket name. Defaults to the attribute name.";
            };
            credentialOwner = lib.mkOption {
              type = lib.types.str;
              default = name;
              description = "System user that reads this bucket's SOPS credentials.";
            };
            consumerService = lib.mkOption {
              type = lib.types.listOf lib.types.str;
              default = singleton "${name}.service";
              description = ''
                Systemd units that consume this bucket and must wait for
                Garage provisioning to complete.
              '';
            };
            accessKeySecretName = lib.mkOption {
              type = lib.types.str;
              default = "${name}/s3_access_key";
              description = "SOPS secret name containing the Garage access key.";
            };
            secretKeySecretName = lib.mkOption {
              type = lib.types.str;
              default = "${name}/s3_secret_key";
              description = "SOPS secret name containing the Garage secret key.";
            };
            accessKeyFile = lib.mkOption {
              type = lib.types.str;
              readOnly = true;
              description = "Decrypted Garage access key path.";
            };
            secretKeyFile = lib.mkOption {
              type = lib.types.str;
              readOnly = true;
              description = "Decrypted Garage secret key path.";
            };
            permissions = {
              read = lib.mkOption {
                type = lib.types.bool;
                default = true;
                description = "Grant read access to the bucket.";
              };
              write = lib.mkOption {
                type = lib.types.bool;
                default = true;
                description = "Grant write access to the bucket.";
              };
              owner = lib.mkOption {
                type = lib.types.bool;
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

  config = lib.mkMerge [
    {
      users.groups.garage = { };
      users.users.garage = {
        isSystemUser = true;
        group = "garage";
      };

      sops.secrets = {
        garage_rpc_secret = {
          key = "garage/rpc_secret";
          owner = "garage";
          restartUnits = [ "garage.service" ];
        };
        garage_default_access_key.key = "garage/default_access_key";
        garage_default_secret_key.key = "garage/default_secret_key";
      };

      sops.templates."garage-default.env" = {
        content = ''
          GARAGE_DEFAULT_ACCESS_KEY=${config.sops.placeholder.garage_default_access_key}
          GARAGE_DEFAULT_SECRET_KEY=${config.sops.placeholder.garage_default_secret_key}
          GARAGE_DEFAULT_BUCKET=default
        '';
        restartUnits = [ "garage.service" ];
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

          s3_api = {
            api_bind_addr = "127.0.0.1:${toString s3_port}";
            s3_region = "garage";
          };
        };
      };

      systemd.services.garage.serviceConfig = {
        DynamicUser = lib.mkForce false;
        User = "garage";
        Group = "garage";
        ExecStart = lib.mkForce ''
          ${lib.getExe pkgs.garage_2} server --single-node --default-bucket
        '';
      };

      mkAllowlistChain.garage = [
        "100.64.0.0/10"
        "fd7a:115c:a1e0::/48"
        "127.0.0.1/32"
        "::1/128"
      ];

      mkTraefikServices.garage = {
        port = s3_port;
        chain = singleton "chain-garage";
      };
    }

    (lib.mkIf (buckets != { }) {
      assertions = lib.mapAttrsToList (name: bucket: {
        assertion = bucket.permissions.read || bucket.permissions.write || bucket.permissions.owner;
        message = "mkGarageBucket.${name} must grant at least one permission";
      }) buckets;

      sops.secrets = lib.listToAttrs (
        lib.concatMap (
          name:
          let
            bucket = buckets.${name};
            restartUnits = [ "${name}-garage-bucket.service" ] ++ bucket.consumerService;
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
        ) (lib.attrNames buckets)
      );

      systemd.services = lib.mapAttrs' (
        name: bucket:
        let
          permissionArgs =
            lib.optional bucket.permissions.read "--read"
            ++ lib.optional bucket.permissions.write "--write"
            ++ lib.optional bucket.permissions.owner "--owner";
          deniedPermissionArgs =
            lib.optional (!bucket.permissions.read) "--read"
            ++ lib.optional (!bucket.permissions.write) "--write"
            ++ lib.optional (!bucket.permissions.owner) "--owner";
        in
        lib.nameValuePair "${name}-garage-bucket" {
          description = "Provision the ${bucket.bucketName} Garage bucket and access key";
          after = [ "garage.service" ];
          requires = [ "garage.service" ];
          wants = [ "sops-install-secrets.service" ];
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
          script = ''
            set -euo pipefail

            if [ ! -s "$CREDENTIALS_DIRECTORY/s3_access_key" ] || [ ! -s "$CREDENTIALS_DIRECTORY/s3_secret_key" ]; then
              echo "ERROR: Garage credentials for ${name} are empty" >&2
              exit 1
            fi

            access_key="$(<"$CREDENTIALS_DIRECTORY/s3_access_key")"
            secret_key="$(<"$CREDENTIALS_DIRECTORY/s3_secret_key")"
            garage=${lib.getExe config.services.garage.package}

            for _ in {1..60}; do
              if "$garage" status > /dev/null 2>&1; then
                break
              fi

              ${lib.getExe' pkgs.coreutils "sleep"} 1
            done

            if ! "$garage" status > /dev/null 2>&1; then
              echo "ERROR: Garage did not become ready within 60 seconds" >&2
              exit 1
            fi

            if ! "$garage" key info "$access_key" > /dev/null 2>&1; then
              "$garage" key import --yes "$access_key" "$secret_key"
            fi

            if ! "$garage" bucket info ${lib.escapeShellArg bucket.bucketName} > /dev/null 2>&1; then
              "$garage" bucket create ${lib.escapeShellArg bucket.bucketName}
            fi

            "$garage" bucket allow ${lib.escapeShellArgs permissionArgs} ${lib.escapeShellArg bucket.bucketName} --key "$access_key"
            ${lib.optionalString (deniedPermissionArgs != [ ]) ''
              "$garage" bucket deny ${lib.escapeShellArgs deniedPermissionArgs} ${lib.escapeShellArg bucket.bucketName} --key "$access_key"
            ''}
          '';
        }
      ) buckets;
    })
  ];
}
