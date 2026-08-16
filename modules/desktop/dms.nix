{ config, ... }:
{
  programs.dms-shell = {
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

  services.displayManager.dms-greeter = {
    enable = true;
    compositor.name = "hyprland";
    configHome = "/home/${config.username}";
  };

  services.displayManager = {
    autoLogin = {
      enable = true;
      user = config.username;
    };

    # Required for auto-login: identifies which session to launch.
    defaultSession = "hyprland";
  };
}
