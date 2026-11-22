{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib.lists) singleton;
  inherit (lib.meta) getExe getExe';
  inherit (lib.strings) escapeShellArg removePrefix;
  firefly = config.services.firefly-iii;
  importer = config.services.firefly-iii-data-importer;
  fireflyRoute = config.mkTraefikServices.firefly;
  importerRoute = config.mkTraefikServices.firefly-importer;

  loopbackListener =
    route:
    singleton {
      addr = route.host;
      inherit (route) port;
    };

  generateAppKey =
    keyFile:
    pkgs.writeShellScript "generate-firefly-app-key" /* bash */ ''
      set -eu
      umask 077
      key_file=${escapeShellArg keyFile}
      if [ ! -s "$key_file" ]; then
        temporary_key="$(${getExe' pkgs.coreutils "mktemp"} "$key_file.XXXXXXXX")"
        trap '${getExe' pkgs.coreutils "rm"} --force -- "$temporary_key"' EXIT
        {
          printf 'base64:'
          ${getExe pkgs.openssl} rand -base64 32
        } > "$temporary_key"
        ${getExe' pkgs.coreutils "mv"} -- "$temporary_key" "$key_file"
      fi
    '';
in
{
  services = {
    firefly-iii = {
      enable = true;
      enableNginx = true;
      virtualHost = removePrefix "https://" fireflyRoute.fullHostname;
      settings = {
        APP_KEY_FILE = "${firefly.dataDir}/app-key";
        DB_CONNECTION = "pgsql";
        DB_DATABASE = firefly.user;
        DB_USERNAME = firefly.user;
        AUTHENTICATION_GUARD = "remote_user_guard";
        AUTHENTICATION_GUARD_HEADER = "HTTP_X_AUTHENTIK_EMAIL";
        TRUSTED_PROXIES = fireflyRoute.host;
        COOKIE_SECURE = true;
      };
    };

    firefly-iii-data-importer = {
      enable = true;
      enableNginx = true;
      virtualHost = removePrefix "https://" importerRoute.fullHostname;
      settings = {
        APP_KEY_FILE = "${importer.dataDir}/app-key";
        APP_URL = importerRoute.fullHostname;
        FIREFLY_III_URL = "http://${fireflyRoute.host}:${toString fireflyRoute.port}";
        VANITY_URL = fireflyRoute.fullHostname;
        TRUSTED_PROXIES = importerRoute.host;
        COOKIE_SECURE = true;
      };
    };

    nginx.virtualHosts = {
      ${firefly.virtualHost}.listen = loopbackListener fireflyRoute;
      ${importer.virtualHost}.listen = loopbackListener importerRoute;
    };

    # The database role matches the service user for Unix socket peer authentication.
    postgresql = {
      ensureDatabases = singleton firefly.settings.DB_DATABASE;
      ensureUsers = singleton {
        name = firefly.settings.DB_USERNAME;
        ensureDBOwnership = true;
      };
    };
  };

  systemd.services = {
    firefly-iii-setup = {
      requires = singleton "postgresql-setup.service";
      after = singleton "postgresql-setup.service";
      serviceConfig.ExecStartPre = generateAppKey firefly.settings.APP_KEY_FILE;
    };

    firefly-iii-data-importer-setup.serviceConfig.ExecStartPre = generateAppKey importer.settings.APP_KEY_FILE;
  };

  mkTraefikServices = {
    firefly = {
      host = "127.0.0.1";
      port = 5006;
      chain = [
        "chain-tailscale"
        "firefly-clear-identity"
        "middlewares-authentik"
      ];
    };

    firefly-importer = {
      host = "127.0.0.1";
      port = 8507;
      chain = [
        "chain-tailscale"
        "middlewares-authentik"
      ];
    };
  };

  services.traefik.dynamicConfigOptions.http.middlewares.firefly-clear-identity.headers.customRequestHeaders.X-Authentik-Email =
    "";

  mkAuthentik.forwardAuthApps = {
    firefly = {
      displayName = "Firefly III";
      displayGroup = "Finance";
      accessGroup = "admins";
    };

    firefly-importer = {
      displayName = "Firefly III Data Importer";
      displayGroup = "Finance";
      accessGroup = "admins";
    };
  };

  mkObservability.inactiveAlertUnits = [
    "phpfpm-firefly-iii.service"
    "phpfpm-firefly-iii-data-importer.service"
  ];
}
