let
  port = 3024;
in
{
  # ConvertX - Self-hosted file converter
  # Reference: hosts/osiris/services/splitpro.nix for full pattern
  myContainerServices.convertx = {
    inherit port;
    manageUser = false;
    containerPort = 3000;
  };

  virtualisation.oci-containers.containers.convertx = {
    image = "ghcr.io/c4illin/convertx:v0.18.0";
    extraOptions = [
      # Intel QuickSync GPU for FFmpeg hardware acceleration
      "--device=/dev/dri:/dev/dri"
    ];
    volumes = [
      "/var/lib/convertx:/app/data"
    ];
    environment = {
      ACCOUNT_REGISTRATION = "false";
      HTTP_ALLOWED = "false";
      ALLOW_UNAUTHENTICATED = "true";
      AUTO_DELETE_EVERY_N_HOURS = "24";
      FFMPEG_ARGS = "-hwaccel qsv";
    };
  };

  myTraefikServices.convertx = {
    inherit port;
    public = true;
  };
}
