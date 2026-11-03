{ inputs, lib, ... }:
let
  inherit (lib.lists) singleton;
in
{
  programs.neovim = {
    enable = true;
    defaultEditor = true;
    vimAlias = true;
    viAlias = true;
  };

  imports = singleton inputs.lazyvim.homeManagerModules.default;
  programs.lazyvim = {
    enable = true;
    ignoreBuildNotifications = true;
  };
}
