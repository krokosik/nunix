{
  osConfig,
  ...
}:
{
  programs.git = {
    enable = true;
    settings = {
      user = {
        name = "krokosik";
        email = "krokosik@pm.me";
      };
      pull.rebase = true;
      init.defaultBranch = "main";
      push.autoSetupRemote = true;
      core.editor = "nvim";
      advice.mergeConflict = false;
      credential.helper = if osConfig.role == "server" then ["cache --timeout 3600" "oauth -device"] else ["libsecret" "oauth"];
      filter.lfs = {
        clean = "git-lfs clean -- %f";
        smudge = "git-lfs smudge -- %f";
        process = "git-lfs filter-process";
        required = true;
      };
    };
  };
}
