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
    unstable.obsidian
    pinta
    proton-vpn
    zotero
  ];
}
