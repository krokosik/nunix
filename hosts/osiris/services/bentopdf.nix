let
  port = 3023;
in
{
  # BentoPDF - Privacy-first PDF toolkit
  # Container runs as UID 101 (image default)
  myContainerServices.bentopdf = {
    inherit port;
    manageUser = false;
    containerPort = 8080;
  };

  virtualisation.oci-containers.containers.bentopdf = {
    image = "ghcr.io/alam00000/bentopdf-simple:v2.8.6";
    volumes = [
      "/var/lib/bentopdf:/config"
    ];
  };

  myTraefikServices.bentopdf = {
    inherit port;
    public = true;
    subdomain = "pdf";
  };
}
