{ config, lib, ... }:
let
  inherit (lib.lists) singleton;
in
{
  # ConvertX - Self-hosted file converter
  # No NixOS module exists in nixpkgs for convertx yet, so it runs as a container.
  # Image runs as root, which rootless Podman maps to the host `convertx` user.
  mkContainerServices.convertx = {
    uid = 2002;
    port = 3024;
    containerPort = 3000;
    # /dev/dri access, passed into the container via keep-groups
    extraGroups = [
      "render"
      "video"
    ];
  };

  virtualisation.oci-containers.containers.convertx = {
    image = "ghcr.io/c4illin/convertx:v0.18.0";
    # Intel QuickSync GPU for FFmpeg hardware acceleration
    devices = singleton "/dev/dri:/dev/dri";
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
    units = singleton config.mkContainerServices.convertx.serviceUnit;
    probes.public = {
      url = config.mkTraefikServices.convertx.fullHostname;
      module = "http_reachable";
    };
  };

  mkObservability.inactiveAlertUnits = config.mkObservabilityServices.convertx.units;
}
