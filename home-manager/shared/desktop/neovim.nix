{ inputs, lib, ... }:
let
  inherit (lib.lists) singleton;
in
{
  imports = singleton inputs.lazyvim.homeManagerModules.default;

  programs = {
    neovim = {
      enable = true;
      defaultEditor = true;
      vimAlias = true;
      viAlias = true;
    };

    lazyvim = {
      enable = true;
      ignoreBuildNotifications = true;
    };
  };
}
