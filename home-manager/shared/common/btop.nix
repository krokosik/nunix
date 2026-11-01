{
  osConfig,
  pkgs,
  ...
}:
{
  programs.btop = {
    enable = true;
    package = if osConfig.hardware.nvidia.enabled then pkgs.btop-cuda else pkgs.btop;

    settings = {
      shown_boxes = "cpu mem net proc gpu0";
      show_gpu_info = "On";
    };
  };
}
