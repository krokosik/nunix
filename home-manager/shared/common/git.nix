{
  config,
  lib,
  osConfig,
  ...
}:
let
  inherit (lib.lists) singleton;
  inherit (lib.meta) getExe';
in
{
  programs.git = {
    enable = true;
    package = osConfig.programs.git.package;

    lfs.enable = true;

    settings = {
      pull.rebase = true;
      init.defaultBranch = "main";
      push.autoSetupRemote = true;
      core.editor = "nvim";
      advice.mergeConflict = false;
      credential.helper = singleton (
        if osConfig.role == "server" then
          "cache --timeout 3600"
        else
          getExe' config.programs.git.package "git-credential-libsecret"
      );
    };
  };

  programs.git-credential-oauth = {
    enable = true;
    extraFlags = lib.mkIf (osConfig.role == "server") (singleton "--device");
  };
}
