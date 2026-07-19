{ config, ... }:
{
  # BentoPDF - Privacy-first PDF toolkit
  # Container runs as UID 101 (image default)
  virtualisation.oci-containers.backend = "docker";

  virtualisation.oci-containers.containers.bentopdf = {
    image = "bentopdf/bentopdf-simple:latest";
    extraOptions = [
      "--network=traefik_proxy"
      "--security-opt=no-new-privileges"
      # Traefik labels
      "--label=traefik.enable=true"
      "--label=traefik.http.routers.bentopdf-rtr.entrypoints=websecure"
      "--label=traefik.http.routers.bentopdf-rtr.rule=Host(`pdf.${config.publicDomain}`)"
      "--label=traefik.http.routers.bentopdf-rtr.middlewares=chain-authentik"
      "--label=traefik.http.routers.bentopdf-rtr.service=bentopdf-svc"
      "--label=traefik.http.services.bentopdf-svc.loadbalancer.server.port=8080"
      "--label=traefik.docker.network=traefik_proxy"
    ];
    volumes = [
      "/var/lib/bentopdf:/config"
    ];
    environment = {
      TZ = config.time.timeZone;
      PUID = "1000";
      PGID = "1000";
    };
  };

  systemd.tmpfiles.rules = [
    "d /var/lib/bentopdf 0755 101 101 -"
  ];
}
