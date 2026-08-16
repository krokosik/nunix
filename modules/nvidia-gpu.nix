{
  config,
  ...
}:
{
  # NVIDIA-only Wayland laptop profile. PRIME offload is intentionally not
  # enabled because this Legion is configured to run on the discrete GPU.
  boot.kernelParams = [ "nvidia_drm.modeset=1" ];

  services.xserver.videoDrivers = [ "nvidia" ];

  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };

  hardware.nvidia = {
    modesetting.enable = true;
    nvidiaSettings = true;
    nvidiaPersistenced = true;
    open = false;
    package = config.boot.kernelPackages.nvidiaPackages.stable;
    videoAcceleration = true;

    dynamicBoost.enable = true;

    powerManagement = {
      enable = true;
      # Requires open kernel modules
      kernelSuspendNotifier = false;
    };
  };
}
