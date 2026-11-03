{ lib, pkgs, ... }:
let
  inherit (lib.lists) singleton;
in
{
  imports = singleton ./autostart.nix;

  home.packages = with pkgs; singleton shotcut;
}
