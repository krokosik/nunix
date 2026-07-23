let
  port = 3024;
in
{
  # ConvertX - Self-hosted file converter
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
    # chain-authentik is the option default; authentik gates the
    # route via the embedded outpost's forward-auth flow.
  };

  # authentik provider + application + policy binding managed via
  # the aggregator in `authentik.nix`. Icon slug matches
  # dashboard-icons/png/<name>.png.
  myAuthentik.forwardAuthApps.convertx = {
    displayName = "ConvertX";
    authentikGroup = "users";
  };
}
