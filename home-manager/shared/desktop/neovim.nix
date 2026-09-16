{ inputs, ... }:
{
  programs.neovim = {
    enable = true;
    defaultEditor = true;
    vimAlias = true;
    viAlias = true;
  };

  imports = [ inputs.lazyvim.homeManagerModules.default ];
  programs.lazyvim.enable = true;
}
