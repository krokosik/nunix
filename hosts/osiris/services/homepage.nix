{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib.lists) forEach;
in
{
  # Minimal website to satisfy Google's OAuth homepage, privacy policy, and terms requirements.
  services.nginx = {
    enable = true;

    virtualHosts."homepage.${config.publicDomain}" = {
      listen = forEach [ "127.0.0.1" "[::1]" ] (addr: {
        inherit addr;
        port = config.mkTraefikServices.homepage.port;
      });

      root = pkgs.runCommand "homelab-homepage" { } /* bash */ ''
        mkdir --parents "$out"
        cp ${../../../docs/oauth-pages}/*.html ${../../../docs/oauth-pages}/style.css "$out/"
      '';
    };
  };

  mkTraefikServices.homepage = {
    port = 8088;
    public = true;
    chain = [ ];
  };
}
