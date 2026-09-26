{
  config,
  pkgs,
  ...
}:
{
  programs.hyprland = {
    enable = true;
    package = pkgs.hyprland;
    portalPackage = pkgs.xdg-desktop-portal-hyprland;
    withUWSM = true;
  };

  services.displayManager.defaultSession = "hyprland-uwsm";

  environment.sessionVariables.UWSM_SILENT_START = "1";
}
