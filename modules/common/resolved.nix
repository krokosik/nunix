{
  config,
  lib,
  ...
}:
let
  nm = config.networking.networkmanager.enable;
  inherit (lib) mkIf;
  ifStatic = mkIf (!nm);
in
{
  networking.nameservers = ifStatic [
    "1.1.1.1#one.one.one.one"
    "1.0.0.1#one.one.one.one"
  ];

  services.resolved = {
    enable = true;

    settings = {
      Resolve = {
        DNSSEC = ifStatic "true";
        MulticastDNS = "resolve";
        Domains = ifStatic [ "~." ];
        DNSOverTLS = ifStatic "true";
      };
    };
  };
}
