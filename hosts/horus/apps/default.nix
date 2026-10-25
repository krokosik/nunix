{ pkgs, ... }:
{
  imports = [
    ./autostart.nix
  ];

  home.packages = with pkgs; [
    shotcut
  ];
}
