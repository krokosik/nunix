{ config, ... }:
let
  inherit (config.xdg)
    cacheHome
    configHome
    dataHome
    stateHome
    ;
in
{
  # as per https://wiki.archlinux.org/title/XDG_Base_Directory#Partial
  home.sessionVariables = {
    # AWS CLI
    AWS_CONFIG_FILE = "${configHome}/aws/config";
    AWS_SHARED_CREDENTIALS_FILE = "${configHome}/aws/credentials";

    # Bash completion
    BASH_COMPLETION_USER_FILE = "${configHome}/bash-completion/bash_completion";

    # CUDA
    CUDA_CACHE_PATH = "${cacheHome}/nv";

    # Docker
    DOCKER_CONFIG = "${configHome}/docker";

    # FFmpeg
    FFMPEG_DATADIR = "${configHome}/ffmpeg";

    # Cargo (Rust)
    CARGO_HOME = "${dataHome}/cargo";

    # GDB
    GDBHISTFILE = "${stateHome}/gdb/history";

    # GnuPG
    GNUPGHOME = "${dataHome}/gnupg";

    # GTK 1 and 2
    GTK_RC_FILES = "${configHome}/gtk-1.0/gtkrc";
    GTK2_RC_FILES = "${configHome}/gtk-2.0/gtkrc:${configHome}/gtk-2.0/gtkrc.mine";

    # Java
    _JAVA_OPTIONS = "-Djava.util.prefs.userRoot=${configHome}/java";

    # Gradle
    GRADLE_USER_HOME = "${dataHome}/gradle";

    # libX11
    XCOMPOSEFILE = "${configHome}/X11/xcompose";
    XCOMPOSECACHE = "${cacheHome}/X11/xcompose";

    # NPM & Node
    NPM_CONFIG_USERCONFIG = "${configHome}/npm/npmrc";
    NPM_CONFIG_CACHE = "${cacheHome}/npm";
    NPM_CONFIG_PREFIX = "${dataHome}/npm";
    NODE_REPL_HISTORY = "${stateHome}/node_repl_history";

    # Mathematica
    WOLFRAM_USERBASE = "${configHome}/Wolfram";

    # mypy
    MYPY_CACHE_DIR = "${cacheHome}/mypy";

    # ncurses
    TERMINFO = "${dataHome}/terminfo";
    TERMINFO_DIRS = "${dataHome}/terminfo:/usr/share/terminfo";

    # Python
    PYTHON_HISTORY = "${stateHome}/python_history";
    PYTHONPYCACHEPREFIX = "${cacheHome}/python";
    PYTHONUSERBASE = "${dataHome}/python";

    # Python setuptools
    PYTHON_EGG_CACHE = "${cacheHome}/python-eggs";

    # Jupyter
    JUPYTER_CONFIG_DIR = "${configHome}/jupyter";
    JUPYTER_PLATFORM_DIRS = "1";

    # Redis
    REDISCLI_HISTFILE = "${dataHome}/redis/rediscli_history";
    REDISCLI_RCFILE = "${configHome}/redis/redisclirc";

    # ripgrep
    RIPGREP_CONFIG_PATH = "${configHome}/ripgrep/config";

    # Ruff
    RUFF_CACHE_DIR = "${cacheHome}/ruff";

    # rustup
    RUSTUP_HOME = "${dataHome}/rustup";

    # OpenAI Codex
    CODEX_HOME = "${configHome}/codex";

    # Wine
    WINEPREFIX = "${dataHome}/wineprefixes/default";
  };

  programs.bash = {
    # Moves ~/.bash_history to ~/.local/state/bash/history
    historyFile = "${stateHome}/bash/history";

    shellAliases = {
      "nvidia-settings" = "nvidia-settings --config=${configHome}/nvidia/settings";
      wget = "wget --hsts-file=${stateHome}/wget-hsts";
      code = "code --extensions-dir ${dataHome}/vscode";
      codium = "codium --extensions-dir ${dataHome}/vscode";
    };
  };

  programs.fish.shellAliases = {
    "nvidia-settings" = "nvidia-settings --config=${configHome}/nvidia/settings";
    wget = "wget --hsts-file=${stateHome}/wget-hsts";
    code = "code --extensions-dir ${dataHome}/vscode";
    codium = "codium --extensions-dir ${dataHome}/vscode";
  };

  home.sessionPath = [
    "${dataHome}/cargo/bin"
    "${dataHome}/npm/bin"
    "${dataHome}/python/bin"
  ];
}
