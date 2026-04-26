{
  # Systemwide ENV variables
  environment.variables = {
    EDITOR = "nvim";
    VISUAL = "nvim";
  };

  documentation.man.generateCaches = false;

  ## Add ~/.local/bin to $PATH
  environment.localBinInPath = true;
}
