{ config, lib, ... }:
let
  inherit (lib.lists) optionals singleton;
in
{
  services.sunshine = {
    # enable is missing from here on purpose. Enable per host in configuration
    autoStart = true;
    capSysAdmin = true;
    openFirewall = true;

    # Use direct Wayland screencopy to avoid the portal picker at login.
    settings.capture = "wlr";
  };

  users.users.${config.username}.extraGroups = optionals (config.services.sunshine.enable) (
    singleton "uinput"
  );
}
