{
  config,
  lib,
  ...
}:
let
  inherit (lib.lists) singleton;
  inherit (lib.modules) mkIf;
  nm = config.networking.networkmanager.enable;
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
        Domains = ifStatic (singleton "~.");
        DNSOverTLS = ifStatic "true";
      };
    };
  };
}
