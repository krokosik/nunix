{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib.lists) singleton;
  inherit (lib.modules) mkIf;
  inherit (lib.options) mkEnableOption;

  units = [
    "authentik.service"
    "authentik-worker.service"
    "authentik-migrate.service"
  ];
in
{
  options.mkAuthentik.google.enable = mkEnableOption "Google sign-in and public enrollment";

  config = mkIf config.mkAuthentik.google.enable {
    sops.secrets = {
      authentik_google_client_id = {
        key = "authentik/google_client_id";
        restartUnits = units;
      };

      authentik_google_client_secret = {
        key = "authentik/google_client_secret";
        restartUnits = units;
      };
    };

    sops.templates."authentik-google.env" = {
      content = /* bash */ ''
        AUTHENTIK_GOOGLE_CLIENT_ID=${config.sops.placeholder.authentik_google_client_id}
        AUTHENTIK_GOOGLE_CLIENT_SECRET=${config.sops.placeholder.authentik_google_client_secret}
      '';
      restartUnits = units;
    };

    systemd.services.authentik.serviceConfig.EnvironmentFile =
      singleton
        config.sops.templates."authentik-google.env".path;

    systemd.services.authentik-worker.serviceConfig.EnvironmentFile =
      singleton
        config.sops.templates."authentik-google.env".path;

    systemd.services.authentik-migrate.serviceConfig.EnvironmentFile =
      singleton
        config.sops.templates."authentik-google.env".path;

    mkAuthentik.extraBlueprints = singleton (
      pkgs.runCommandLocal "authentik-google-blueprint" { } /* bash */ ''
        mkdir --parents "$out"
        cp ${./authentik-blueprints/google-source.yaml} "$out/google-source.yaml"
      ''
    );
  };
}
