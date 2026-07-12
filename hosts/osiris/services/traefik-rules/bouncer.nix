{ config, lib, ... }:
lib.mkIf (config.services.traefik.enable && config.services.crowdsec.enable) {
  services.traefik.staticConfigOptions = {
    experimental.plugins.crowdsec = {
      moduleName = "github.com/maxlerebourg/crowdsec-bouncer-traefik-plugin";
      version = "v1.5.1";
    };
  };

  services.traefik.dynamicConfigOptions.http.middlewares = {

    middlewares-crowdsec-bouncer.plugin.crowdsec = {
      enabled = true;
      crowdsecAppsecEnabled = true;
      crowdsecAppsecHost = "127.0.0.1:7422";
      crowdsecAppsecFailureBlock = true;
      crowdsecAppsecUnreachableBlock = true;
      crowdsecLapiScheme = "http";
      crowdsecLapiHost = config.services.crowdsec.settings.general.api.server.listen_uri;
      crowdsecLapiKeyFile = config.sops.secrets.crowdsec_traefik_bouncer_key.path;
      clientTrustedIPs = [
        "10.0.0.0/8"
        "172.16.0.0/12"
        "192.168.0.0/16"
        "100.64.0.0/10"
      ];
    };

  };

  sops.secrets.crowdsec_traefik_bouncer_key = {
    key = "crowdsec/traefik_bouncer_key";
    mode = "0440";
    owner = config.users.users.traefik.name;
    group = config.users.users.traefik.group;
    restartUnits = [ "traefik.service" ];
  };
}
