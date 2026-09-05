{
  config,
  inputs,
  lib,
  ...
}:
{
  imports = [
    ./disko-config.nix
    ./surface.nix
    ./power.nix
    inputs.nixos-hardware.nixosModules.microsoft-surface-pro-intel
    ../../modules/boot-limine.nix
    ../../modules/desktop
    ../../modules/hibernation.nix
  ];

  # Generated on this Surface Pro 8 with run0 nix run github:numtide/nixos-facter.
  hardware.facter.reportPath = ./facter.json;

  role = "desktop";

  hardware.microsoft-surface.kernelVersion = "stable";

  # Enroll boot keys explicitly after checking Surface UEFI support and backups.
  boot.loader.limine.secureBoot.autoEnrollKeys.enable = lib.modules.mkForce false;

  # Keep kernel builds within the tablet's memory budget.
  nix.settings = {
    max-jobs = 1;
    cores = 2;
  };

  home-manager.users.${config.username} = {
    imports = [
      ../../home-manager/base.nix
      ../../home-manager/desktop
      ./apps
    ];
  };

  system.stateVersion = "26.05";
}
