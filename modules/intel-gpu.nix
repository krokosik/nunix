{
  config,
  lib,
  pkgs,
  ...
}:
{
  ## Enable OpenGL accelerated video playback
  ## https://wiki.nixos.org/wiki/Intel_Graphics
  hardware.graphics = {
    enable = true;
    extraPackages = with pkgs; [
      intel-media-driver
      intel-compute-runtime # 13th gen and newer
      vpl-gpu-rt # 11th gen and newer
    ];
  };

  hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;

  environment.sessionVariables = {
    LIBVA_DRIVER_NAME = "iHD";
  };
}
