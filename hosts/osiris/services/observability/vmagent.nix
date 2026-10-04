{ config, lib, ... }:
let
  listenerFlag = lib.lists.findFirst (
    flag: lib.strings.hasPrefix "-httpListenAddr=" flag
  ) "" config.services.vmagent.extraArgs;
in
{
  mkTraefikServices.vmagent = {
    host = "127.0.0.1";
    port = lib.toInt (
      lib.lists.last (lib.splitString ":" (lib.removePrefix "-httpListenAddr=" listenerFlag))
    );
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
