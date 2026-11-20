{ lib, pkgs, ... }:
let
  inherit (lib.lists) singleton;
in
{
  imports = singleton ./autostart.nix;

  home.packages = with pkgs; singleton shotcut;

  desktop.hyprland.windowRules = singleton {
    name = "hookshot-game-fullscreen";
    match = {
      class = "^io\\.github\\.NotRexed\\.Hookshot$";
      initial_title = "^Hookshot$";
    };
    fullscreen = true;
  };
}
