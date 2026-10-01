{ config, lib, ... }:
let
  inherit (lib) singleton optionals;
in
{
  services.sunshine = {
    # enable is missing from here on purpose. Enable per host in configuration
    autoStart = true;
    capSysAdmin = true;
    openFirewall = true;
  };

  users.users.${config.username}.extraGroups = optionals (config.services.sunshine.enable) (
    singleton "uinput"
  );
}
