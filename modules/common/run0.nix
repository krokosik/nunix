{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib.lists) singleton;
  inherit (lib.modules) mkIf;
in
{
  environment.systemPackages = singleton pkgs.run0-sudo-shim;

  security = {
    sudo.enable = false;

    polkit = {
      enable = true;

      # TODO: Replace with security.run0.persistentAuth.enable after NixOS 26.11 is released.
      extraConfig = mkIf config.security.run0.wheelNeedsPassword /* javascript */ ''
        polkit.addRule(function(action, subject) {
          if (action.id == "org.freedesktop.systemd1.manage-units" &&
              subject.isInGroup("wheel")) {
            return polkit.Result.AUTH_ADMIN_KEEP;
          }
        });
      '';
    };
  };
}
