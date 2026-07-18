{
  config,
  lib,
  pkgs,
  ...
}:
let
  dbUser = "splitpro";
  containerUser = config.username; # UID/GID 1000 on osiris
in
{
  # --- PostgreSQL extensions and settings (service-first) ---
  services.postgresql = {
    extensions = pp: [ pp.pg_cron ];
    settings = {
      shared_preload_libraries = [ "pg_cron" ];
      "cron.database_name" = dbUser;
      "cron.timezone" = "UTC";
    };

    ensureDatabases = [ dbUser ];
    ensureUsers = [
      {
        name = dbUser;
        ensureDBOwnership = true;
      }
    ];
  };

  # Set splitpro user password (sops-secured; ensureClauses would put the
  # hash in the nix store/git repo) and create pg_cron extension (per-DB;
  # NixOS has no ensureExtensions). DB ownership is declarative via
  # ensureDBOwnership, so no ALTER DATABASE here.
  # Grant splitpro access to the cron schema (created by pg_cron, owned by
  # postgres) so the app can manage its scheduled jobs.
  # postgresql-setup.postStart is types.lines — merges with postgresql.nix.
  systemd.services.postgresql-setup.postStart = lib.mkAfter ''
    PGPW=$(cat ${config.sops.secrets.splitpro_db_password.path})
    psql -d postgres -c "ALTER USER \"${dbUser}\" WITH PASSWORD '$PGPW';"
    psql -d "${dbUser}" -c "CREATE EXTENSION IF NOT EXISTS pg_cron;"
    psql -d "${dbUser}" -c "GRANT USAGE ON SCHEMA cron TO \"${dbUser}\";"
    psql -d "${dbUser}" -c "GRANT ALL ON ALL TABLES IN SCHEMA cron TO \"${dbUser}\";"
    psql -d "${dbUser}" -c "GRANT ALL ON ALL SEQUENCES IN SCHEMA cron TO \"${dbUser}\";"
  '';

  # --- Sops secrets ---
  # splitpro_db_password is read by postgresql-setup (runs as postgres) to
  # ALTER USER password. The container only mounts the rendered DATABASE_URL
  # template (which embeds the password), not this secret.
  sops.secrets = {
    splitpro_db_password = {
      key = "splitpro/db_password";
      owner = config.users.users.postgres.name;
      restartUnits = [
        "postgresql-setup.service"
        "docker-splitpro.service"
      ];
    };
    splitpro_nextauth_secret = {
      key = "splitpro/nextauth_secret";
      owner = containerUser;
      restartUnits = [ "docker-splitpro.service" ];
    };
    splitpro_authentik_id = {
      key = "splitpro/authentik_id";
      owner = containerUser;
      restartUnits = [ "docker-splitpro.service" ];
    };
    splitpro_authentik_secret = {
      key = "splitpro/authentik_secret";
      owner = containerUser;
      restartUnits = [ "docker-splitpro.service" ];
    };
    splitpro_webpush_public_key = {
      key = "splitpro/webpush_public_key";
      owner = containerUser;
      restartUnits = [ "docker-splitpro.service" ];
    };
    splitpro_webpush_private_key = {
      key = "splitpro/webpush_private_key";
      owner = containerUser;
      restartUnits = [ "docker-splitpro.service" ];
    };
  };

  # Build DATABASE_URL from parts (password from sops, rest inline)
  sops.templates."splitpro_database_url" = {
    content = "postgresql://${dbUser}:${config.sops.placeholder.splitpro_db_password}@host.docker.internal:5432/${dbUser}";
    owner = containerUser;
    restartUnits = [ "docker-splitpro.service" ];
  };

  # --- Persistent uploads directory ---
  systemd.tmpfiles.rules = [
    "d /var/lib/splitpro/uploads 0755 1000 1000 -"
  ];

  # --- Docker container ---
  # Force docker backend (oci-containers defaults to podman on this host)
  virtualisation.oci-containers.backend = "docker";
  virtualisation.oci-containers.containers.splitpro = {
    image = "ossapps/splitpro:v2.1.4";
    user = "1000:1000";
    extraOptions = [
      "--network=traefik_proxy"
      "--add-host=host.docker.internal:host-gateway"
      "--security-opt=no-new-privileges"
      # Traefik labels (docker-label style, matching legacy compose)
      "--label=traefik.enable=true"
      "--label=traefik.http.routers.splitpro-rtr.entrypoints=websecure"
      "--label=traefik.http.routers.splitpro-rtr.rule=Host(`splitpro.${config.publicDomain}`)"
      "--label=traefik.http.routers.splitpro-rtr.middlewares=chain-no-auth@file"
      "--label=traefik.http.routers.splitpro-rtr.service=splitpro-svc"
      "--label=traefik.http.services.splitpro-svc.loadbalancer.server.port=3000"
      "--label=traefik.docker.network=traefik_proxy"
    ];
    volumes = [
      "/var/lib/splitpro/uploads:/app/uploads"
      "${config.sops.secrets.splitpro_nextauth_secret.path}:/run/secrets/splitpro_nextauth_secret:ro"
      "${config.sops.templates."splitpro_database_url".path}:/run/secrets/splitpro_database_url:ro"
      "${config.sops.secrets.splitpro_authentik_id.path}:/run/secrets/splitpro_authentik_id:ro"
      "${config.sops.secrets.splitpro_authentik_secret.path}:/run/secrets/splitpro_authentik_secret:ro"
      "${config.sops.secrets.splitpro_webpush_public_key.path}:/run/secrets/splitpro_webpush_public_key:ro"
      "${config.sops.secrets.splitpro_webpush_private_key.path}:/run/secrets/splitpro_webpush_private_key:ro"
    ];
    environment = {
      HOSTNAME = "0.0.0.0";
      DEFAULT_HOMEPAGE = "/balances";
      NEXTAUTH_URL = "https://splitpro.${config.publicDomain}";
      NEXTAUTH_SECRET_FILE = "/run/secrets/splitpro_nextauth_secret";
      DATABASE_URL_FILE = "/run/secrets/splitpro_database_url";
      ENABLE_SENDING_INVITES = "false";
      CURRENCY_RATE_PROVIDER = "nbp";
      AUTHENTIK_ID_FILE = "/run/secrets/splitpro_authentik_id";
      AUTHENTIK_SECRET_FILE = "/run/secrets/splitpro_authentik_secret";
      AUTHENTIK_ISSUER = "https://authentik.${config.publicDomain}/application/o/splitpro";
      WEB_PUSH_PUBLIC_KEY_FILE = "/run/secrets/splitpro_webpush_public_key";
      WEB_PUSH_PRIVATE_KEY_FILE = "/run/secrets/splitpro_webpush_private_key";
    };
  };

  # Container depends on postgres being fully set up (DB, user, extension created).
  # docker backend creates docker-<name>.service with ExecStart; we only add
  # ordering constraints (merge into the generated unit, not replace it).
  systemd.services.docker-splitpro = {
    after = [ "postgresql.target" ];
    requires = [ "postgresql.target" ];
  };
}
