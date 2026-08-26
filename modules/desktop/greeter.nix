{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib.meta) getExe;
  inherit (lib.strings) escapeShellArgs;
in
{
  security.pam.services.greetd = {
    enableGnomeKeyring = true;
    rules.auth.systemd_loadkey = {
      order = config.security.pam.services.greetd.rules.auth.unix-early.order - 10;
      control = "optional";
      modulePath = "${config.systemd.package}/lib/security/pam_systemd_loadkey.so";
    };
  };

  services.gnome.gnome-keyring.enable = true;

  services.greetd = {
    enable = true;
    useTextGreeter = true;
    settings.default_session = {
      command = escapeShellArgs [
        (getExe pkgs.tuigreet)
        "--remember"
        "--cmd"
        "${getExe config.programs.uwsm.package} start -e -D Hyprland hyprland.desktop"
      ];
      user = "greeter";
    };
  };

  systemd = {
    services = {
      greetd.serviceConfig.KeyringMode = lib.mkForce "inherit";
      plymouth-quit.after = [ "greetd.service" ];
    };

    tmpfiles.settings."11-tuigreet-last-user"."/var/cache/tuigreet/lastuser".f = {
      user = "greeter";
      group = "greeter";
      mode = "0644";
      argument = config.username;
    };
  };
}
