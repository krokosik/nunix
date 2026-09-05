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
    ../../modules/boot-limine.nix
    ../../modules/desktop
    ../../modules/hibernation.nix
    # ../../modules/power.nix
  ];

  # Add the report generated with `run0 nix run github:numtide/nixos-facter --
  # --output hosts/horus/facter.json` before evaluating or deploying this host.
  hardware.facter.reportPath = ./facter.json;
  
  # hardware.nvidia.branch = "legacy_580";

  role = "desktop";

  boot.initrd = {
    # we don't use nvidia gpu, as we let nixos-hardware set the configs
    kernelModules = [
      "nvidia"
      "nvidia_modeset"
      "nvidia_uvm"
      "nvidia_drm"
    ];
  };

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
