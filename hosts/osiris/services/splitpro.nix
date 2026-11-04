{
  config,
  lib,
  ...
}:
let
  inherit (lib.lists) singleton;
  name = "splitpro";
  db = config.mkPostgresServices.splitpro.dbName;
  oidc = config.mkAuthentik.oidcApps.splitpro;
  containerUser = config.username; # UID/GID 1000 on osiris
  containerUnit = "${config.virtualisation.oci-containers.backend}-${name}.service";
in
{
  mkPostgresServices.splitpro = {
    extraCommands = [
      "CREATE EXTENSION IF NOT EXISTS pg_cron;"
      "GRANT USAGE ON SCHEMA cron TO \"${db}\";"
      "GRANT ALL ON ALL TABLES IN SCHEMA cron TO \"${db}\";"
      "GRANT ALL ON ALL SEQUENCES IN SCHEMA cron TO \"${db}\";"
    ];
  };

  # --- POSTGRESQL EXTENSIONS ---
  services.postgresql = {
    extensions = pp: singleton pp.pg_cron;
    settings = {
      shared_preload_libraries = singleton "pg_cron";
      "cron.database_name" = db;
      "cron.timezone" = "UTC";
    };
  };

  mkContainerServices.splitpro = {
    port = 3000;
    stateDirs = singleton "/var/lib/splitpro/uploads";
  };

  mkAuthentik.oidcApps.splitpro = {
    displayName = "SplitPro";
    displayGroup = "Finance";
    accessGroup = "users";
    iconUrl = "https://raw.githubusercontent.com/krokosik/split-pro/main/public/logo_circle.png";
    launchUrl = "${config.mkTraefikServices.splitpro.fullHostname}/auth/signin";
    redirectUris = singleton "${config.mkTraefikServices.splitpro.fullHostname}/api/auth/callback/authentik";
    logoutUri = "${config.mkTraefikServices.splitpro.fullHostname}/api/auth/signout";
  };

  sops = {
    secrets = {
      nextauth_secret.key = "splitpro/nextauth_secret";
      webpush_public_key.key = "splitpro/webpush_public_key";
      webpush_private_key.key = "splitpro/webpush_private_key";
      webpush_email.key = "splitpro/webpush_email";
    };
    templates."splitpro.env" = {
      content = /* bash */ ''
        NEXTAUTH_SECRET=${config.sops.placeholder.nextauth_secret}
        DATABASE_URL=postgresql://${db}:${
          config.sops.placeholder.${config.mkPostgresServices.splitpro.secretName}
        }@host.docker.internal:5432/${db}
        AUTHENTIK_ID=${config.sops.placeholder.${oidc.credentials.clientId.secretName}}
        AUTHENTIK_SECRET=${config.sops.placeholder.${oidc.credentials.clientSecret.secretName}}
        WEB_PUSH_PUBLIC_KEY=${config.sops.placeholder.webpush_public_key}
        WEB_PUSH_PRIVATE_KEY=${config.sops.placeholder.webpush_private_key}
        WEB_PUSH_EMAIL=${config.sops.placeholder.webpush_email}
      '';

      owner = containerUser;
      restartUnits = singleton containerUnit;
    };
  };

  mkTraefikServices.splitpro = {
    port = config.mkContainerServices.splitpro.port;
    public = true;
    chain = singleton "chain-no-auth";
  };

  mkObservabilityServices.splitpro = {
    units = singleton containerUnit;
    probes.public.url = config.mkTraefikServices.splitpro.fullHostname;
  };

  mkObservability.inactiveAlertUnits = config.mkObservabilityServices.splitpro.units;

  virtualisation.oci-containers.containers.splitpro = {
    image = "ossapps/splitpro:v2.1.5";
    extraOptions = singleton "--add-host=host.docker.internal:host-gateway";
    volumes = singleton "/var/lib/splitpro/uploads:/app/uploads";
    environment = {
      HOSTNAME = "0.0.0.0";
      DEFAULT_HOMEPAGE = "/balances";
      NEXTAUTH_URL = config.mkTraefikServices.splitpro.fullHostname;
      ENABLE_SENDING_INVITES = "false";
      CURRENCY_RATE_PROVIDER = "nbp";
      AUTHENTIK_ISSUER = oidc.issuerUrl;
    };
    environmentFiles = singleton config.sops.templates."splitpro.env".path;
  };
}
