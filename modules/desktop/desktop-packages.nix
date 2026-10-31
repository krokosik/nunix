{ pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    gparted
    kdePackages.kdenlive
    vlc
  ];
}
