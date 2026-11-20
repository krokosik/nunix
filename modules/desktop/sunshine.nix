{ config, lib, ... }:
let
  inherit (lib.lists) optionals singleton;
in
{
  services.sunshine = {
    # enable is missing from here on purpose. Enable per host in configuration
    autoStart = true;
    capSysAdmin = false;
    openFirewall = true;

    # Use direct Wayland screencopy to avoid the portal picker at login.
    settings.capture = "wlr";
  };

  systemd.user.services.sunshine.environment.LD_LIBRARY_PATH = "/run/opengl-driver/lib";

  users.users.${config.nunix.self.user}.extraGroups = optionals (config.services.sunshine.enable) (
    singleton "uinput"
  );
}
