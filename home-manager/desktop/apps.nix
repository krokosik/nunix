{ pkgs, ... }:
{
  home.packages = with pkgs; [
    beeper
    freecad
    imv
    mpv
    inkscape
    libreoffice
    localsend
    mattermost-desktop
    moonlight-qt
    obsidian
    pinta
  ];
}
