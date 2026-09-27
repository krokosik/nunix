{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:
let
  names = [
    "metrics"
    "logs"
  ];
  paths = {
    metrics = "/api/v1/write";
    logs = "/insert/native";
  };
  ports = {
    metrics = 8428;
    logs = 9428;
  };
in
{
  sops.secrets = {
    observability_metrics_ingest_password = {
      key = "observability/metrics_ingest_password";
      restartUnits = [
        "observability-ingest-auth.service"
        "traefik.service"
      ];
      sopsFile = "${inputs.my-secrets}/common/secrets.yaml";
    };
    observability_logs_ingest_password = {
      key = "observability/logs_ingest_password";
      restartUnits = [
        "observability-ingest-auth.service"
        "traefik.service"
      ];
      sopsFile = "${inputs.my-secrets}/common/secrets.yaml";
    };
  };

  # The rendered htpasswd file must stay out of the Nix store.
  systemd.services.observability-ingest-auth = {
    description = "Render observability ingestion Basic Auth users";
    before = [ "traefik.service" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      User = "root";
      Group = "observability-ingest-auth";
      RuntimeDirectory = "observability-ingest-auth";
      RuntimeDirectoryMode = "0750";
      UMask = "0027";
      LoadCredential = [
        "metrics:${config.sops.secrets.observability_metrics_ingest_password.path}"
        "logs:${config.sops.secrets.observability_logs_ingest_password.path}"
      ];
    };
    script = ''
      set -euo pipefail
      for name in metrics logs; do
        secret="$CREDENTIALS_DIRECTORY/$name"
        test -s "$secret"
        ${lib.getExe' pkgs.apacheHttpd "htpasswd"} -niB "anubis-$name" < "$secret" > "/run/observability-ingest-auth/$name"
        ${lib.getExe' pkgs.coreutils "chmod"} 0640 "/run/observability-ingest-auth/$name"
      done
    '';
  };

  systemd.services.traefik = {
    wants = [ "observability-ingest-auth.service" ];
    after = [ "observability-ingest-auth.service" ];
  };

  users.groups.observability-ingest-auth = { };

  users.users.traefik.extraGroups = [ "observability-ingest-auth" ];

  services.traefik.dynamicConfigOptions.http = {
    services = lib.genAttrs names (name: {
      loadBalancer.servers = [ { url = "http://127.0.0.1:${toString ports.${name}}"; } ];
    });
    routers = lib.genAttrs names (name: {
      rule = "Host(`${name}-ingest.${config.privateDomain}`) && Path(`${paths.${name}}`) && Method(`POST`)";
      entryPoints = [ "websecure" ];
      service = name;
      middlewares = [
        "observability-ingest-source"
        name
      ];
    });
    middlewares = {
      observability-ingest-source.ipAllowList.sourceRange = [ "${config.vpsPrivateIp}/32" ];
    }
    // lib.genAttrs names (name: {
      basicAuth.usersFile = "/run/observability-ingest-auth/${name}";
    });
  };
}
