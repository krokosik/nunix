{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib.modules) mkDefault;
in
{
  ## ENABLE OPENGL ACCELERATED VIDEO PLAYBACK
  ## https://wiki.nixos.org/wiki/Intel_Graphics
  hardware = {
    graphics = {
      enable = true;
      extraPackages = with pkgs; [
        intel-media-driver
        intel-compute-runtime # 13th gen and newer
        vpl-gpu-rt # 11th gen and newer
      ];
    };

    cpu.intel.updateMicrocode = mkDefault config.hardware.enableRedistributableFirmware;
  };

  environment.sessionVariables = {
    LIBVA_DRIVER_NAME = "iHD";
  };
}
