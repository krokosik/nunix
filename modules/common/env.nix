{
  # Systemwide ENV variables
  environment.variables = {
    EDITOR = "nvim";
    VISUAL = "nvim";
  };

  documentation.man.cache.enable = false;

  ## Add ~/.local/bin to $PATH
  environment.localBinInPath = true;
}
