{ pkgs, ... }:
{
  home.packages = with pkgs; [
    beeper
    codex
    freecad
    imv
    mpv
    inkscape
    libreoffice
    mattermost-desktop
    moonlight-qt
    obsidian
    pinta
  ];
}
