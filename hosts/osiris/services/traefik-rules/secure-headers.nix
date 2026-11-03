{ lib, ... }:
let
  inherit (lib.lists) singleton;
in
{
  services.traefik.dynamicConfigOptions.http.middlewares = {

    middlewares-secure-headers.headers = {
      accessControlAllowMethods = [
        "GET"
        "OPTIONS"
        "PUT"
      ];
      accessControlMaxAge = 100;
      hostsProxyHeaders = singleton "X-Forwarded-Host";
      stsSeconds = 63072000;
      stsIncludeSubdomains = true;
      stsPreload = true;
      customFrameOptionsValue = "SAMEORIGIN";
      contentTypeNosniff = true;
      browserXssFilter = true;
      referrerPolicy = "same-origin";
      permissionsPolicy = "camera=(), microphone=(), geolocation=(), payment=(), usb=(), vr=()";
      customResponseHeaders = {
        X-Robots-Tag = "none,noarchive,nosnippet,notranslate,noimageindex,";
        server = "";
      };
    };

  };
}
