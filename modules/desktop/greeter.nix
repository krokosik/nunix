{
  config,
  inputs,
  lib,
  ...
}:
{
  imports = [ inputs.dank-greeter.nixosModules.default ];

  programs.dms-greeter = {
    enable = true;
    compositor.name = "hyprland";
    configHome = "/home/${config.username}";
  };

  security.pam.services.greetd = {
    enableGnomeKeyring = true;
    rules.auth.systemd_loadkey = {
      order = config.security.pam.services.greetd.rules.auth.unix-early.order - 10;
      control = "optional";
      modulePath = "${config.systemd.package}/lib/security/pam_systemd_loadkey.so";
    };
  };

  services.gnome.gnome-keyring.enable = true;

  services.greetd.settings.default_session.user = "greeter";

  systemd.services.greetd = {
    after = [ "plymouth-quit.service" ];
    serviceConfig = {
      KeyringMode = lib.mkForce "inherit";
      StandardError = "journal";
    };
  };

  systemd.services."user@".serviceConfig.StandardError = "journal";
}
