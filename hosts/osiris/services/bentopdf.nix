{ config, lib, ... }:
let
  inherit (lib.lists) singleton;
in
{
  # BentoPDF - Privacy-first PDF toolkit
  # Image runs as UID 101; keep-id maps it onto the host `bentopdf` user.
  mkContainerServices.bentopdf = {
    uid = 2001;
    ctrUid = 101;
    port = 3023;
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
    units = singleton config.mkContainerServices.bentopdf.serviceUnit;
    probes.public = {
      url = config.mkTraefikServices.bentopdf.fullHostname;
      module = "http_reachable";
    };
  };

  mkObservability.inactiveAlertUnits = config.mkObservabilityServices.bentopdf.units;
}
