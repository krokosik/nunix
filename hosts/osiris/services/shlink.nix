{ config, ... }:
{
  # Shlink - URL shortener
  # Container runs as UID 1001 (image default)
  # NOTE: legacy compose did not mount the sqlite DB — data was lost on
  # container recreation. This config mounts /var/lib/shlink to
  # /etc/shlink/data to persist the DB.
  virtualisation.oci-containers.backend = "docker";

  virtualisation.oci-containers.containers.shlink = {
    image = "shlinkio/shlink:stable";
    extraOptions = [
      "--network=traefik_proxy"
      "--security-opt=no-new-privileges"
      # Traefik labels
      "--label=traefik.enable=true"
      "--label=traefik.http.routers.shlink-rtr.entrypoints=websecure"
      "--label=traefik.http.routers.shlink-rtr.rule=Host(`s.${config.publicDomain}`)"
      "--label=traefik.http.routers.shlink-rtr.middlewares=chain-no-auth@file"
      "--label=traefik.http.routers.shlink-rtr.service=shlink-svc"
      "--label=traefik.http.services.shlink-svc.loadbalancer.server.port=8080"
      "--label=traefik.docker.network=traefik_proxy"
    ];
    volumes = [
      "/var/lib/shlink:/etc/shlink/data"
    ];
    environment = {
      DEFAULT_DOMAIN = "s.${config.publicDomain}";
      IS_HTTPS_ENABLED = "true";
      DB_DRIVER = "sqlite";
      DEFAULT_QR_CODE_ERROR_CORRECTION = "H";
      TZ = config.time.timeZone;
    };
  };

  systemd.tmpfiles.rules = [
    "d /var/lib/shlink 0755 1001 1001 -"
  ];
}
