{
  config,
  lib,
  ...
}:
let
  inherit (lib.lists) singleton;
in
{
  # NVIDIA-only Wayland laptop profile. PRIME offload is intentionally not
  # enabled because this Legion is configured to run on the discrete GPU.
  boot = {
    kernelParams = singleton "nvidia_drm.modeset=1";
    # Load the complete KMS stack before the greeter probes external outputs.
    initrd.kernelModules = [
      "nvidia"
      "nvidia_modeset"
      "nvidia_uvm"
      "nvidia_drm"
    ];
  };

  services.xserver.videoDrivers = singleton "nvidia";

  hardware = {
    graphics = {
      enable = true;
      enable32Bit = true;
    };

    nvidia = {
      modesetting.enable = true;
      nvidiaSettings = true;
      nvidiaPersistenced = true;
      open = true;
      package = config.boot.kernelPackages.nvidiaPackages.stable;
      videoAcceleration = true;

      dynamicBoost.enable = true;

    };
  };
}
