{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib.lists) singleton;
  inherit (lib.meta) getExe;
  inherit (lib.strings) escapeShellArg;
  wgetExe = getExe pkgs.wget;

  inherit (config.xdg)
    cacheHome
    configHome
    dataHome
    stateHome
    ;
in
{
  # Fish enables these caches by default, which creates ~/.manpath.
  programs = {
    man.generateCaches = false;

    bash = {
      # Moves ~/.bash_history to ~/.local/state/bash/history
      historyFile = "${stateHome}/bash/history";

      shellAliases = {
        # nvidia-settings and code resolve through PATH on purpose: the former is
        # provided by the installed GPU driver, the latter by the user's editor.
        "nvidia-settings" = "nvidia-settings --config=${configHome}/nvidia/settings";
        wget = "${wgetExe} --hsts-file=${stateHome}/wget-hsts";
        code = "code --extensions-dir ${dataHome}/vscode";
      };
    };

    fish.shellAliases = {
      "nvidia-settings" = "nvidia-settings --config=${configHome}/nvidia/settings";
      wget = "${wgetExe} --hsts-file=${stateHome}/wget-hsts";
      code = "code --extensions-dir ${dataHome}/vscode";
    };
  };

  xresources.path = "${configHome}/X11/xresources";

  home = {
    preferXdgDirectories = true;

    # as per https://wiki.archlinux.org/title/XDG_Base_Directory#Partial
    sessionVariables = {
      # AWS CLI
      AWS_CONFIG_FILE = "${configHome}/aws/config";
      AWS_SHARED_CREDENTIALS_FILE = "${configHome}/aws/credentials";

      # BASH COMPLETION
      BASH_COMPLETION_USER_FILE = "${configHome}/bash-completion/bash_completion";

      # CUDA
      CUDA_CACHE_PATH = "${cacheHome}/nv";

      # DOCKER
      DOCKER_CONFIG = "${configHome}/docker";

      # FFMPEG
      FFMPEG_DATADIR = "${configHome}/ffmpeg";

      # CARGO (RUST)
      CARGO_HOME = "${dataHome}/cargo";

      # GDB
      GDBHISTFILE = "${stateHome}/gdb/history";

      # POSTGRESQL
      PSQL_HISTORY = "${stateHome}/psql/history";

      # GNUPG
      GNUPGHOME = "${dataHome}/gnupg";

      # JAVA
      _JAVA_OPTIONS = "-Djava.util.prefs.userRoot=${configHome}/java";

      # GRADLE
      GRADLE_USER_HOME = "${dataHome}/gradle";

      # LIBX11
      XCOMPOSEFILE = "${configHome}/X11/xcompose";
      XCOMPOSECACHE = "${cacheHome}/X11/xcompose";

      # NPM & NODE
      NPM_CONFIG_USERCONFIG = "${configHome}/npm/npmrc";
      NPM_CONFIG_CACHE = "${cacheHome}/npm";
      NPM_CONFIG_PREFIX = "${dataHome}/npm";
      NODE_REPL_HISTORY = "${stateHome}/node_repl_history";

      # MATHEMATICA
      WOLFRAM_USERBASE = "${configHome}/Wolfram";
      WOLFRAM_LOCALBASE = "${configHome}/Wolfram/Objects";

      # MYPY
      MYPY_CACHE_DIR = "${cacheHome}/mypy";

      # PYTHON
      PYTHON_HISTORY = "${stateHome}/python_history";
      PYTHONPYCACHEPREFIX = "${cacheHome}/python";
      PYTHONUSERBASE = "${dataHome}/python";

      # IPYTHON
      IPYTHONDIR = "${configHome}/ipython";

      # PYTHON SETUPTOOLS
      PYTHON_EGG_CACHE = "${cacheHome}/python-eggs";

      # JUPYTER
      JUPYTER_CONFIG_DIR = "${configHome}/jupyter";
      JUPYTER_PLATFORM_DIRS = "1";

      # REDIS
      REDISCLI_HISTFILE = "${dataHome}/redis/rediscli_history";
      REDISCLI_RCFILE = "${configHome}/redis/redisclirc";

      # RUFF
      RUFF_CACHE_DIR = "${cacheHome}/ruff";

      # RUSTUP
      RUSTUP_HOME = "${dataHome}/rustup";

      # OPENAI CODEX
      CODEX_HOME = "${configHome}/codex";

      # CLAUDE CODE
      CLAUDE_CONFIG_DIR = "${configHome}/claude";

      # WINE
      WINEPREFIX = "${dataHome}/wineprefixes/default";
    };

    activation.createPsqlHistoryDirectory = config.lib.dag.entryAfter (singleton "writeBoundary") /* bash */ ''
      run mkdir --parents ${escapeShellArg "${stateHome}/psql"}
      run chmod 0700 ${escapeShellArg "${stateHome}/psql"}
    '';

    sessionPath = [
      "${dataHome}/cargo/bin"
      "${dataHome}/npm/bin"
      "${dataHome}/python/bin"
    ];
  };
}
