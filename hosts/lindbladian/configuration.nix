{
  config,
  inputs,
  lib,
  ...
}:
let
  inherit (lib.lists) singleton;
  inherit (lib.modules) mkForce;
in
{
  imports = [
    ./sunshine.nix
    ./build-host.nix
    ./dsearch.nix
    ./disko-config.nix
    inputs.nixos-hardware.nixosModules.common-cpu-intel-cpu-only
    inputs.nixos-hardware.nixosModules.common-gpu-nvidia-nonprime
    inputs.nixos-hardware.nixosModules.common-pc-ssd
    ../../modules/boot-limine.nix
    ../../modules/desktop
    ../../modules/desktop/cad.nix
    ../../modules/mathematica.nix
  ];

  role = "desktop";

  desktop.windows.partition = {
    device = "/dev/disk/by-uuid/40A886D1A886C53E";
    guid = "2fa87be4-5c65-11ee-94c6-c44e12b486e6";
  };

  extraUsers = singleton "lab";

  desktop.sambaMounts.allUsers = true;

  nunix.voxtype.server.enable = true;

  boot = {
    initrd.kernelModules = [
      "nvidia"
      "nvidia_modeset"
      "nvidia_uvm"
      "nvidia_drm"
    ];

    # support building for anubis
    binfmt.emulatedSystems = singleton "aarch64-linux";
  };

  hardware = {
    # Generated on lindbladian with `run0 nix run github:numtide/nixos-facter`.
    facter.reportPath = ./facter.json;

    graphics = {
      enable = true;
      enable32Bit = true;
    };

    nvidia = {
      modesetting.enable = true;
      open = true;
      branch = "latest";
    };
  };

  stylix.image = mkForce ../../wallpapers/wallpaper_thz.jpg;

  home-manager.users.${config.nunix.self.user} = {
    imports = [
      ../../home-manager/private/desktop
      ../../home-manager/rea.nix
      ../../home-manager/computer-use.nix
      ../../home-manager/agent-workspace.nix
    ];
  };

  services = {
    # COMPUTER USE ACCESSIBILITY
    gnome.at-spi2-core.enable = true;
  };

  system.stateVersion = "26.05";
}
