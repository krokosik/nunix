{ config, pkgs, ... }:

{
  home.username = "krokosik";
  home.homeDirectory = "/home/krokosik";

  # Link dotfiles
  home.file = {
    ".bashrc".source = ../../dotfiles/bash/.bashrc;
    ".bash_profile".source = ../../dotfiles/bash/.bash_profile;
    ".local/bin".source = ../../dotfiles/bin/.local/bin;
    ".config/fastfetch".source = ../../dotfiles/fastfetch/.config/fastfetch;
    ".config/fish".source = ../../dotfiles/fish/.config/fish;
    ".gitconfig".source = ../../dotfiles/git/.gitconfig;
    ".gitconfig.lab".source = ../../dotfiles/git/.gitconfig.lab;
    ".config/mise".source = ../../dotfiles/mise/.config/mise;
    ".config/nvim".source = ../../dotfiles/nvim/.config/nvim;
    ".config/pypoetry".source = ../../dotfiles/poetry/.config/pypoetry;
    # Skip mapping .ssh/id_kws.pub or let it be if it's there
    ".ssh/config".source = ../../dotfiles/ssh/.ssh/config;
    ".config/starship.toml".source = ../../dotfiles/starship/.config/starship.toml;
  };

  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;

  home.stateVersion = "25.11";
}
