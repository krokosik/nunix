{
  inputs,
  pkgs,
  ...
}:
{
  # Use Hyprland's upstream module so the compositor and its portal stay in
  # lockstep. The module also supplies the compositor-specific desktop
  # integration (polkit, dconf, Xwayland, and the desktop entry).
  imports = [ inputs.hyprland.nixosModules.default ];

  programs.hyprland = {
    enable = true;
    package = inputs.hyprland.packages.${pkgs.stdenv.hostPlatform.system}.hyprland;
    portalPackage = inputs.hyprland.packages.${pkgs.stdenv.hostPlatform.system}.xdg-desktop-portal-hyprland;
    withUWSM = true;
  };
}
