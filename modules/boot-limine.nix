{
  config,
  pkgs,
  lib,
  ...
}:
{
  environment.systemPackages = with pkgs; [
    sbctl
    plymouth
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
    plymouth = lib.mkIf (config.role == "desktop") {
      enable = true;
    };
  };
}
