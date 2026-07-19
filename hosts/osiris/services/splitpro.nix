{
  config,
  ...
}:
let
  name = "splitpro";
  port = 3000;
  dbUser = name;
  containerUser = config.username; # UID/GID 1000 on osiris
  containerUnit = "${config.virtualisation.oci-containers.backend}-${name}.service";
in
{
  myPostgresServices.splitpro = {
    extraCommands = [
      "CREATE EXTENSION IF NOT EXISTS pg_cron;"
      "GRANT USAGE ON SCHEMA cron TO \"${dbUser}\";"
      "GRANT ALL ON ALL TABLES IN SCHEMA cron TO \"${dbUser}\";"
      "GRANT ALL ON ALL SEQUENCES IN SCHEMA cron TO \"${dbUser}\";"
    ];
  };

  # --- PostgreSQL extensions ---
  services.postgresql = {
    extensions = pp: [ pp.pg_cron ];
    settings = {
      shared_preload_libraries = [ "pg_cron" ];
      "cron.database_name" = dbUser;
      "cron.timezone" = "UTC";
    };
  };

  myContainerServices.splitpro = {
    inherit port;
    stateDirs = [ "/var/lib/splitpro/uploads" ];
  };

  sops = {
    secrets = {
      nextauth_secret.key = "splitpro/nextauth_secret";
      authentik_id.key = "splitpro/authentik_id";
      authentik_secret.key = "splitpro/authentik_secret";
      webpush_public_key.key = "splitpro/webpush_public_key";
      webpush_private_key.key = "splitpro/webpush_private_key";
    };
    templates."splitpro.env" = {
      content = ''
        NEXTAUTH_SECRET=${config.sops.placeholder.nextauth_secret}
        DATABASE_URL=postgresql://${dbUser}:${
          config.sops.placeholder.${config.myPostgresServices.splitpro.secretName}
        }@host.docker.internal:5432/${dbUser}
        AUTHENTIK_ID=${config.sops.placeholder.authentik_id}
        AUTHENTIK_SECRET=${config.sops.placeholder.authentik_secret}
        WEB_PUSH_PUBLIC_KEY=${config.sops.placeholder.webpush_public_key}
        WEB_PUSH_PRIVATE_KEY=${config.sops.placeholder.webpush_private_key}
      '';

      owner = containerUser;
      restartUnits = [ containerUnit ];
    };
  };

  myTraefikServices.splitpro = {
    inherit port;
    public = true;
    chain = [ "chain-no-auth" ];
  };

  virtualisation.oci-containers.containers.splitpro = {
    image = "ossapps/splitpro:v2.1.4";
    extraOptions = [
      "--add-host=host.docker.internal:host-gateway"
    ];
    volumes = [
      "/var/lib/splitpro/uploads:/app/uploads"
    ];
    environment = {
      HOSTNAME = "0.0.0.0";
      DEFAULT_HOMEPAGE = "/balances";
      NEXTAUTH_URL = "https://splitpro.${config.publicDomain}";
      ENABLE_SENDING_INVITES = "false";
      CURRENCY_RATE_PROVIDER = "nbp";
      AUTHENTIK_ISSUER = "https://authentik.${config.publicDomain}/application/o/splitpro";
    };
    environmentFiles = [
      config.sops.templates."splitpro.env".path
    ];
  };
}
