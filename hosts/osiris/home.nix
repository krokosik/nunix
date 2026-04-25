{ config, pkgs, ... }:

{
  home.username = "krokosik";
  home.homeDirectory = "/home/krokosik";

  # Link dotfiles
  home.file = {
    ".config/bash".source = ../../dotfiles/bash;
    ".config/bin".source = ../../dotfiles/bin;
    ".config/fastfetch".source = ../../dotfiles/fastfetch;
    ".config/fish".source = ../../dotfiles/fish;
    ".config/git".source = ../../dotfiles/git;
    ".config/mise".source = ../../dotfiles/mise;
    ".config/nvim".source = ../../dotfiles/nvim;
    ".config/poetry".source = ../../dotfiles/poetry;
    ".config/ssh".source = ../../dotfiles/ssh;
    ".config/starship".source = ../../dotfiles/starship;
  };

  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;

  home.stateVersion = "25.11";
}
