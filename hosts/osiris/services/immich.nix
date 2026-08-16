{
  config,
  lib,
  pkgs,
  ...
}:
{
  # ==========================================
  # Immich Configuration
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
    };
  };

  mkPostgresServices.immich = { };

  services.postgresql = {
    extensions = ps: with ps; lib.singleton vectorchord;
    initdbArgs = [ "--data-checksums" ];
  };

  mkTraefikServices.immich = {
    public = true;
    chain = [ "chain-no-auth" ];
    port = config.services.immich.port;
  };
}
