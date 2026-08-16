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
    open = true;
    package = config.boot.kernelPackages.nvidiaPackages.stable;
    videoAcceleration = true;

    dynamicBoost.enable = true;

    # Nvidia power management. Experimental, and can cause sleep/suspend to fail.
    # Enable this if you have graphical corruption issues or application crashes after waking
    # up from sleep. This fixes it by saving the entire VRAM memory to /tmp/ instead 
    # of just the bare essentials.
    powerManagement = {
      enable = true;
      # Requires open kernel modules
      kernelSuspendNotifier = true;
    };
  };
}
