{config, ... }:
{
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
}
