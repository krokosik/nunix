{
  programs = {
    uv = {
      enable = true;

      settings = {
        python-preference = "only-managed";
      };

      # wait for 26.11
      # tool = {
      #   packages = [
      #     "ruff"
      #     "poetry"
      #     "basedpyright"
      #     "jupyter"
      #     "pre-commit"
      #   ];
      #   prune = true;
      # };
    };

    poetry.settings.virtualenvs = {
      create = true;
      in-project = true;
      use-poetry-python = false;
    };
  };
}
