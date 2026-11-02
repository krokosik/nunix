{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib.modules) mkIf;
  inherit (lib.lists) singleton;
in
{
  environment.systemPackages = singleton pkgs.run0-sudo-shim;

  security.sudo.enable = false;

  security.polkit.enable = true;

  # TODO: Replace with security.run0.persistentAuth.enable after NixOS 26.11 is released.
  security.polkit.extraConfig = mkIf config.security.run0.wheelNeedsPassword /* javascript */ ''
    polkit.addRule(function(action, subject) {
      if (action.id == "org.freedesktop.systemd1.manage-units" &&
          subject.isInGroup("wheel")) {
        return polkit.Result.AUTH_ADMIN_KEEP;
      }
    });
  '';
}
