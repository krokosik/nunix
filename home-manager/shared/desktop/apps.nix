{ pkgs, ... }:
{
  home.packages = with pkgs; [
    brave
    imv
    mpv
    inkscape
    libreoffice
    localsend
    mattermost-desktop
    moonlight-qt
    obsidian
    parsec-bin
    pinta
    proton-vpn
    zotero
  ];
}
