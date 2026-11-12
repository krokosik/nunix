{
  config,
  inputs,
  pkgs,
  ...
}:

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

    plugins = {
      quickCapture.enable = true;
      voxTypeOsd.enable = true;
      calculator.enable = true;
      emojiLauncher.enable = true;
      aiOverviewControl.enable = true;
    };

  };

  systemd.user.services.dms.environment = {
    inherit (config.home-manager.users.${config.username}.home.sessionVariables)
      CODEX_HOME
      CLAUDE_CONFIG_DIR
      ;
  };

  # PLUGIN DEPS
  environment.systemPackages = with pkgs; [
    # QUICK CAPTURE
    ffmpeg
    gpu-screen-recorder
    imagemagick
    img2pdf
    tesseract
    zbar
  ];
}
