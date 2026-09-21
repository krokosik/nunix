{ inputs, pkgs, ... }:

{
  imports = [
    inputs.dms.nixosModules.dank-material-shell
    inputs.dms-plugin-registry.nixosModules.default
  ];

  programs.dank-material-shell = {
    enable = true;
    enableAudioWavelength = true;
    enableCalendarEvents = false;
    enableSystemMonitoring = true;
    enableVPN = true;

    systemd = {
      enable = true;
      restartIfChanged = true;
    };

    plugins.quickCapture.enable = true;
  };

  # plugin deps
  environment.systemPackages = with pkgs; [
    # quick capture
    ffmpeg
    gpu-screen-recorder
    imagemagick
    img2pdf
    tesseract
    zbar
  ];
}
