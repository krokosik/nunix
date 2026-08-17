{ config, pkgs, ... }:
{
  programs.dms-shell = {
    enable = true;
    package = pkgs.unstable.dms-shell;
    quickshell.package = pkgs.unstable.quickshell;
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
    package = config.programs.dms-shell.package;
    quickshell.package = config.programs.dms-shell.quickshell.package;
    compositor.name = "hyprland";
    configHome = "/home/${config.username}";
  };

  services.displayManager = {
    autoLogin = {
      enable = true;
      user = config.username;
    };

    # Required for auto-login: identifies which session to launch.
    defaultSession = "hyprland-uwsm";
  };
}
