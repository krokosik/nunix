{ pkgs, ... }:
{
  programs.hyprland = {
    enable = true;
    package = pkgs.hyprland;
    portalPackage = pkgs.unstable.xdg-desktop-portal-hyprland;
    withUWSM = true;
  };
}
