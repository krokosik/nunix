{ config, pkgs, ... }:
{
  programs.hyprland = {
    enable = true;
    package = pkgs.hyprland;
    portalPackage = pkgs.xdg-desktop-portal-hyprland;
    withUWSM = true;
  };
  # Required for auto-login: identifies which session to launch.
  services.displayManager.defaultSession = "hyprland${
    if config.programs.hyprland.withUWSM then "-uwsm" else ""
  }";
}
