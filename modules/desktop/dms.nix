{
  config,
  pkgs,
  lib,
  ...
}:
let
  luksEncryptionEnabled = config.boot.initrd.luks.devices != { };
  tpm2UnlockEnabled = lib.any (
    device: lib.any (option: lib.hasPrefix "tpm2-device=" option) device.crypttabExtraOpts
  ) (lib.attrValues config.boot.initrd.luks.devices);
in
{
  programs.dms-shell = {
    enable = true;
    enableAudioWavelength = true;
    enableCalendarEvents = false;
    enableSystemMonitoring = true;
    enableVPN = true;

    systemd = {
      enable = true;
      restartIfChanged = true;
    };

    # For sha, use nix store prefetch-file --unpack --json <link to tar.gz>
    plugins = {
      screenRecorderLH = {
        src = pkgs.fetchFromGitHub {
          owner = "hthienloc";
          repo = "dms-screen-recorder";
          rev = "v1.1";
          sha256 = "sha256-Gd7beNQYGnSlEyyE3hRnHEWXOhIMqlA1TNL1fFJR2FE=";
        };
      };
    };
  };

  services.displayManager = {
    autoLogin = {
      enable = luksEncryptionEnabled && !tpm2UnlockEnabled;
      user = config.username;
    };

    dms-greeter = {
      enable = true;
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
