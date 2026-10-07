{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:
{
  imports = [
    ./disko-config.nix
    ./windows.nix
    inputs.nixos-hardware.nixosModules.common-cpu-intel-cpu-only
    inputs.nixos-hardware.nixosModules.common-gpu-nvidia-nonprime
    inputs.nixos-hardware.nixosModules.common-pc-ssd
    ../../modules/boot-limine.nix
    ../../modules/desktop
  ];

  # Generated on lindbladian with `run0 nix run github:numtide/nixos-facter`.
  hardware.facter.reportPath = ./facter.json;

  role = "desktop";
  extraUsers = [ "lab" ];

  desktop.sambaMounts.allUsers = true;

  boot.initrd.kernelModules = [
    "nvidia"
    "nvidia_modeset"
    "nvidia_uvm"
    "nvidia_drm"
  ];

  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };

  hardware.nvidia = {
    modesetting.enable = true;
    open = true;
    branch = "latest";
  };

  stylix.image = lib.mkForce ../../wallpapers/wallpaper_thz.jpg;

  username = "wkrokosz";

  # support building for anubis
  boot.binfmt.emulatedSystems = [ "aarch64-linux" ];

  home-manager.users.${config.username} = {
    imports = [
      ../../home-manager/private/desktop
    ];

    home.packages = with pkgs; [
      freecad
    ];
  };

  services.sunshine.enable = true;

  system.stateVersion = "26.05";
}
