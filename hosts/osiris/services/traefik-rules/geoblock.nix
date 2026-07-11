{
  services.traefik.dynamicConfigOptions.http.middlewares = {

    experimental.plugins.geoblock = {
      moduleName = "github.com/nscuro/traefik-plugin-geoblock";
      version = "v0.14.0";
    };

    middlewares-geoblock.plugin.geoblock = {
      enabled = true;
      databaseFilePath = "/var/lib/traefik/plugins/IP2LOCATION-LITE-DB1.IPV6.BIN";
      allowedCountries = [
        "PL"
        "FR"
      ];
      blockedCountries = [ ];
      defaultAllow = false;
      allowPrivate = true;
      disallowedStatusCode = 403;
      allowedIPBlocks = [
        "10.0.0.0/8"
        "172.16.0.0/12"
        "192.168.0.0/16"
        "100.64.0.0/10"
      ];
    };

  };
}
