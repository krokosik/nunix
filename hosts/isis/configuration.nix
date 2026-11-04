{
  config,
  inputs,
  lib,
  ...
}:
let
  inherit (lib.lists) singleton;
in
{
  imports = [
    ./disko-config.nix
    ./surface.nix
    ./tablet-mode.nix
    ./tablet-plugins.nix
    inputs.nixos-hardware.nixosModules.microsoft-surface-pro-intel
    ../../modules/boot-limine.nix
    ../../modules/btop-intel-gpu.nix
    ../../modules/desktop
    ../../modules/hibernation.nix
    ../../modules/media-share.nix
  ];

  hardware = {
    # Generated on this Surface Pro 8 with run0 nix run github:numtide/nixos-facter.
    facter.reportPath = ./facter.json;

    microsoft-surface.kernelVersion = "stable";
  };

  role = "desktop";

  extraUsers = singleton "guest";

  # Suspend on a short press, like a tablet lock button.
  services.logind.settings.Login.HandlePowerKey = "suspend";

  # Keep kernel builds within the tablet's memory budget.
  nix.settings = {
    max-jobs = 1;
    cores = 2;
  };

  home-manager.users.${config.username} = {
    imports = [
      ../../home-manager/private/desktop
      ./voxtype-remote.nix
    ];
  };

  system.stateVersion = "26.05";
}
