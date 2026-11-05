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
    pinta
    proton-vpn
    zotero
  ];

  programs.obsidian = {
    enable = true;
    package = pkgs.unstable.obsidian;
    cli.enable = true;
  };
}
