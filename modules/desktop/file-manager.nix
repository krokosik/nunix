{ pkgs, ... }:
{
  services.gvfs.enable = true;
  services.udisks2.enable = true;

  xdg.portal.extraPortals = [ pkgs.xdg-desktop-portal-gtk ];

  environment.systemPackages = with pkgs; [
    file-roller
    nautilus
    sushi
  ];
}
