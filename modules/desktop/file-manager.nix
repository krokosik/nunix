{ lib, pkgs, ... }:
let
  inherit (lib.lists) singleton;
in
{
  services = {
    gvfs.enable = true;
    udisks2.enable = true;
  };

  xdg.portal.extraPortals = singleton pkgs.xdg-desktop-portal-gtk;

  environment.systemPackages = with pkgs; [
    file-roller
    nautilus
    sushi
  ];
}
