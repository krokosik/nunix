{ config, lib, ... }:
let
  inherit (lib.lists) findFirst last;
  inherit (lib.strings)
    hasPrefix
    removePrefix
    splitString
    toInt
    ;
  listenerFlag = findFirst (
    flag: hasPrefix "-httpListenAddr=" flag
  ) "" config.services.vmagent.extraArgs;
in
{
  mkTraefikServices.vmagent = {
    host = "127.0.0.1";
    port = toInt (last (splitString ":" (removePrefix "-httpListenAddr=" listenerFlag)));
    chain = [
      "chain-tailscale"
      "chain-authentik"
    ];
  };

  mkAuthentik.forwardAuthApps.vmagent = {
    displayName = "VMAgent — Osiris";
    launchUrl = "${config.mkTraefikServices.vmagent.fullHostname}/targets";
    iconUrl = config.mkAuthentik.forwardAuthApps.victoriametrics.iconUrl;
    accessGroup = "admins";
    displayGroup = "Infrastructure";
  };
}
