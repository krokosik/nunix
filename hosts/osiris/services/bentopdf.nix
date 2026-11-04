{ config, lib, ... }:
let
  inherit (lib.lists) singleton;
in
{
  # BentoPDF - Privacy-first PDF toolkit
  # Container runs as UID 101 (image default)
  mkContainerServices.bentopdf = {
    port = 3023;
    manageUser = false;
    containerPort = 8080;
  };

  virtualisation.oci-containers.containers.bentopdf = {
    image = "ghcr.io/alam00000/bentopdf-simple:v2.8.6";
    volumes = singleton "/var/lib/bentopdf:/config";
  };

  mkTraefikServices.bentopdf = {
    port = config.mkContainerServices.bentopdf.port;
    public = true;
    subdomain = "pdf";
  };

  mkAuthentik.forwardAuthApps.bentopdf = {
    displayName = "PDF";
    accessGroup = "users";
    displayGroup = "Apps";
    host = config.mkTraefikServices.bentopdf.fullHostname;
  };

  mkObservabilityServices.bentopdf = {
    units = singleton "docker-bentopdf.service";
    probes.public = {
      url = config.mkTraefikServices.bentopdf.fullHostname;
      module = "http_reachable";
    };
  };

  mkObservability.inactiveAlertUnits = config.mkObservabilityServices.bentopdf.units;
}
