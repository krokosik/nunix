{ config, lib, ... }:
let
  inherit (lib.lists) singleton;
in
{
  # ConvertX - Self-hosted file converter
  # No NixOS module exists in nixpkgs for convertx yet, so it runs as a container.
  mkContainerServices.convertx = {
    port = 3024;
    manageUser = false;
    containerPort = 3000;
  };

  virtualisation.oci-containers.containers.convertx = {
    image = "ghcr.io/c4illin/convertx:v0.18.0";
    # Intel QuickSync GPU for FFmpeg hardware acceleration
    extraOptions = singleton "--device=/dev/dri:/dev/dri";
    volumes = singleton "/var/lib/convertx:/app/data";
    environment = {
      ACCOUNT_REGISTRATION = "false";
      HTTP_ALLOWED = "false";
      ALLOW_UNAUTHENTICATED = "true";
      AUTO_DELETE_EVERY_N_HOURS = "24";
      FFMPEG_ARGS = "-hwaccel qsv";
    };
  };

  mkTraefikServices.convertx = {
    port = config.mkContainerServices.convertx.port;
    public = true;
    # chain-authentik is the option default; authentik gates the
    # route via the embedded outpost's forward-auth flow.
  };

  # authentik provider + application + policy binding managed via
  # the aggregator in `authentik.nix`. Icon slug matches
  # dashboard-icons/png/<name>.png.
  mkAuthentik.forwardAuthApps.convertx = {
    displayName = "ConvertX";
    accessGroup = "friends";
    displayGroup = "Apps";
  };

  mkObservabilityServices.convertx = {
    units = singleton "docker-convertx.service";
    probes.public = {
      url = config.mkTraefikServices.convertx.fullHostname;
      module = "http_reachable";
    };
  };

  mkObservability.inactiveAlertUnits = config.mkObservabilityServices.convertx.units;
}
