{
  lib,
  ...
}:
let
  inherit (lib.lists) singleton;
in
{
  security.rtkit.enable = true;

  services.pipewire = {
    enable = true;
    alsa.enable = true;
    pulse.enable = true;
    wireplumber = {
      enable = true;

      # Keep Bluetooth headsets on stereo playback without call-profile negotiation.
      extraConfig."90-playback-only" = {
        "monitor.bluez.properties"."bluez5.roles" = singleton "a2dp_source";
      };
    };
  };
}
