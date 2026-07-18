{ config, ... }:
{
  # ConvertX - Self-hosted file converter
  # Reference: hosts/osiris/services/splitpro.nix for full pattern
  virtualisation.oci-containers.backend = "docker";

  virtualisation.oci-containers.containers.convertx = {
    image = "ghcr.io/c4illin/convertx";
    extraOptions = [
      "--network=traefik_proxy"
      "--security-opt=no-new-privileges"
      # Intel QuickSync GPU for FFmpeg hardware acceleration
      "--device=/dev/dri:/dev/dri"
      # Traefik labels
      "--label=traefik.enable=true"
      "--label=traefik.http.routers.convertx-rtr.entrypoints=websecure"
      "--label=traefik.http.routers.convertx-rtr.rule=Host(`convertx.${config.publicDomain}`)"
      "--label=traefik.http.routers.convertx-rtr.middlewares=chain-authentik@file"
      "--label=traefik.http.routers.convertx-rtr.service=convertx-svc"
      "--label=traefik.http.services.convertx-svc.loadbalancer.server.port=3000"
      "--label=traefik.docker.network=traefik_proxy"
    ];
    volumes = [
      "/var/lib/convertx:/app/data"
    ];
    environment = {
      TZ = config.time.timeZone;
      PUID = "1000";
      PGID = "1000";
      ACCOUNT_REGISTRATION = "false";
      HTTP_ALLOWED = "false";
      ALLOW_UNAUTHENTICATED = "true";
      AUTO_DELETE_EVERY_N_HOURS = "24";
      FFMPEG_ARGS = "-hwaccel qsv";
    };
  };

  systemd.tmpfiles.rules = [
    "d /var/lib/convertx 0755 1000 1000 -"
  ];
}
