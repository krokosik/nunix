{
  inputs,
  ...
}:
{
  imports = [ inputs.dms.homeModules.dank-material-shell ];

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
  };
}
