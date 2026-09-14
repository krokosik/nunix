{ pkgs, ... }:
{

  boot = {
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
  };
}
