{
  # SYSTEMWIDE ENV VARIABLES
  environment = {
    variables = {
      EDITOR = "nvim";
      VISUAL = "nvim";
    };

    ## Add ~/.local/bin to $PATH
    localBinInPath = true;
  };

  documentation.man.cache.enable = false;
}
