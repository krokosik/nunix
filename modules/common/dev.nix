{ config, pkgs, ... }:
{
  imports = [ ../nix-ld.nix ];

  environment.systemPackages = with pkgs; [
    uv
    ruff
    nodejs
  ];

  home.sessionVariables = {
    # Cargo (Rust)
    CARGO_HOME = "${config.xdg.dataHome}/cargo";

    # NPM & Node
    NPM_CONFIG_USERCONFIG = "${config.xdg.configHome}/npm/npmrc";
    NPM_CONFIG_CACHE = "${config.xdg.cacheHome}/npm";
    NPM_CONFIG_PREFIX = "${config.xdg.dataHome}/npm";
    NODE_REPL_HISTORY = "${config.xdg.stateHome}/node_repl_history";

    # Python
    PYTHONUSERBASE = "${config.xdg.dataHome}/python";
    # Supported in Python >= 3.13
    PYTHON_HISTORY = "${config.xdg.stateHome}/python/history";
    # Workaround for Python <= 3.12 to respect XDG for history
    PYTHONSTARTUP = "${config.xdg.configHome}/python/pythonrc";
  };

  programs.bash = {
    # Moves ~/.bash_history to ~/.local/state/bash/history
    historyFile = "${config.xdg.stateHome}/bash/history";
  };

  home.sessionPath = [
    "${config.xdg.dataHome}/cargo/bin"
    "${config.xdg.dataHome}/npm/bin"
    "${config.xdg.dataHome}/python/bin"
  ];

  # Workaround script to force Python <= 3.12 to respect XDG for history
  xdg.configFile."python/pythonrc".text = ''
    import os
    import atexit
    import readline

    history = os.path.join(os.environ.get('XDG_STATE_HOME', os.path.expanduser('~/.local/state')), 'python', 'history')
    try:
        os.makedirs(os.path.dirname(history), exist_ok=True)
        readline.read_history_file(history)
    except OSError:
        pass

    def write_history():
        try:
            readline.write_history_file(history)
        except OSError:
            pass

    atexit.register(write_history)
  '';
}
