{ pkgs, ... }:
{
  home.packages = with pkgs; [
    brave
    imv
    mpv
    libreoffice
    localsend
    mattermost-desktop
    moonlight-qt
    obsidian
    pinta
    proton-vpn
    zotero
  ];
}
