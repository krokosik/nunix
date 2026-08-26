{ config, lib, ... }:
let
  luksEncryptionEnabled = config.boot.initrd.luks.devices != { };
  tpm2UnlockEnabled = lib.any (
    device: lib.any (option: lib.hasPrefix "tpm2-device=" option) device.crypttabExtraOpts
  ) (lib.attrValues config.boot.initrd.luks.devices);
in
{
  security.pam.services.greetd = {
      enableGnomeKeyring = true;
      rules.auth.systemd_loadkey = {
        order = 11500; # Ensures this runs before pam_kwallet (which typically runs >12000)
        control = "optional";
        modulePath = "${config.systemd.package}/lib/security/pam_systemd_loadkey.so";
      };
  };

  services.gnome.gnome-keyring.enable = true;
  systemd.services.greetd.serviceConfig.KeyringMode = lib.mkForce "inherit";

services.displayManager = {
    autoLogin = {
      enable = luksEncryptionEnabled && !tpm2UnlockEnabled;
      user = config.username;
    };

    dms-greeter = {
      enable = false;
      compositor = {
        name = "hyprland";
        customConfig = ''
          env = DMS_RUN_GREETER,1

          misc {
              disable_hyprland_logo = true
          }
        '';
      };
      configHome = "/home/${config.username}";
    };
  };

  systemd.services.plymouth-quit = lib.mkIf (!config.services.displayManager.autoLogin.enable) {
    after = [ "greetd.service" ];
  };
}
