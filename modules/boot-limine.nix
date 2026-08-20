{
  config,
  pkgs,
  lib,
  ...
}:
let
  isDesktop = (config.role == "desktop");
in
{
  environment.systemPackages = lib.mkIf isDesktop [
    pkgs.sbctl
    pkgs.plymouth
  ];

  # Limine Configuration with plymouth
  boot = {
    consoleLogLevel = 0;
    kernelParams = [
      "quiet"
      "udev.log_level=0"
      "splash"
      "loglevel=0"
      "systemd.show_status=0"
      "vt.global_cursor_default=0"
    ];
    initrd = {
      systemd = {
        enable = true;
      };
      verbose = false;
    };
    loader = {
      limine = {
        enable = true;
        maxGenerations = 10;
        efiSupport = pkgs.stdenv.hostPlatform.isEfi;
        enrollConfig = true;
        secureBoot = {
          enable = true;
          autoGenerateKeys = true;
          autoEnrollKeys.enable = true;
        };
      };
      efi = {
        efiSysMountPoint = "/boot";
        canTouchEfiVariables = true;
      };
    };
    plymouth = lib.mkIf isDesktop {
      enable = true;
    };
  };

  # hold on the plymouth splash screen for longer
  systemd.services = lib.mkIf isDesktop {
    plymouth-quit = {
      wantedBy = lib.mkForce [ "graphical.target" ];
      after = [ "multi-user.target" ];
    };
    plymouth-quit-wait.enable = false;
  };
}
