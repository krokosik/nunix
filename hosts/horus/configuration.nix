{
  config,
  inputs,
  ...
}:
{
  imports = [
    ./disko-config.nix
    ./windows.nix
    inputs.nixos-hardware.nixosModules.lenovo-legion-15ach6h-nvidia
    ../../modules/avahi.nix
    ../../modules/boot-limine.nix
    ../../modules/common
    ../../modules/desktop
    ../../modules/nvidia-gpu.nix
    ../../modules/desktop/theme.nix
    ../../modules/hibernation.nix
    # ../../modules/power.nix
    ../../home-manager/home-manager.nix
    inputs.disko.nixosModules.disko
    inputs.home-manager.nixosModules.home-manager
    inputs.sops-nix.nixosModules.sops
  ];

  # Add the report generated with `run0 nix run github:numtide/nixos-facter --
  # --output hosts/horus/facter.json` before evaluating or deploying this host.
  hardware.facter.reportPath = ./facter.json;

  role = "desktop";

  # support building for anubis
  boot.binfmt.emulatedSystems = [ "aarch64-linux" ];

  home-manager.users.${config.username} = {
    imports = [
      ../../home-manager/base.nix
      ../../home-manager/desktop
      ./apps
    ];
  };

  system.stateVersion = "26.05";
}
