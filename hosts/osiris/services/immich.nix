{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib.lists) singleton;
  inherit (lib.modules) mkIf;
  oidc = config.mkAuthentik.oidcApps.immich;
in
{
  # ==========================================
  # IMMICH CONFIGURATION
  # ==========================================
  services.immich = {
    enable = true;

    # Enable all devices
    accelerationDevices = null;

    package = pkgs.unstable.immich;

    redis.enable = true;

    machine-learning = {
      enable = true;
      environment = {
        MACHINE_LEARNING_WORKERS = "1";
        MACHINE_LEARNING_WORKER_TIMEOUT = "120";
      };
    };

    settings = {
      server.externalDomain = config.mkTraefikServices.immich.fullHostname;
      newVersionCheck.enabled = false;
      oauth = {
        enabled = true;
        clientId._secret = config.sops.secrets.${oidc.credentials.clientId.secretName}.path;
        clientSecret._secret = config.sops.secrets.${oidc.credentials.clientSecret.secretName}.path;
        issuerUrl = oidc.issuerUrl;
        buttonText = "Authentik";
      };
    };
  };

  mkAuthentik.oidcApps.immich = {
    displayName = "Immich";
    displayGroup = "Apps";
    accessGroup = "family";
    launchUrl = "${config.mkTraefikServices.immich.fullHostname}/auth/login?autoLaunch=1";
    redirectUris = [
      "${config.mkTraefikServices.immich.fullHostname}/auth/login"
      "${config.mkTraefikServices.immich.fullHostname}/user-settings"
      "app.immich:///oauth-callback"
    ];
    logoutMethod = "backchannel";
    logoutUri = "${config.mkTraefikServices.immich.fullHostname}/api/oauth/backchannel-logout";
  };

  systemd.services.immich-server.unitConfig.RequiresMountsFor =
    singleton config.services.immich.mediaLocation;

  mkPostgresServices.immich = { };

  services.postgresql = {
    extensions = ps: with ps; singleton vectorchord;
    initdbArgs = singleton "--data-checksums";
  };

  mkTraefikServices.immich = {
    public = true;
    chain = singleton "chain-no-auth";
    port = config.services.immich.port;
  };

  mkObservabilityServices.immich = {
    units = singleton "immich-server.service";
    probes.public = {
      url = "${config.mkTraefikServices.immich.fullHostname}/api/server/ping";
    };
  };

  mkObservability.inactiveAlertUnits = mkIf config.services.immich.enable config.mkObservabilityServices.immich.units;
}
