{ pkgs, ... }:
{
  home.packages = with pkgs; [
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
    proton-vpn
  ];
}
