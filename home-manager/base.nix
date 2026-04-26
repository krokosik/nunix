{
  config,
  osConfig,
  inputs,
  ...
}:
let
  secretspath = builtins.toString inputs.my-secrets;
in
{
  home.username = osConfig.username;
  home.homeDirectory = "/home/${osConfig.username}";
  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;

  sops = {
    age.keyFile = "${config.xdg.configHome}/sops/age/keys.txt";
    defaultSopsFile = "${secretspath}/${osConfig.networking.hostName}/secrets.yaml";
  };

  # This value determines the Home Manager release that your
  # configuration is compatible with. This helps avoid breakage
  # when a new Home Manager release introduces backwards
  # incompatible changes.
  #
  # You can update Home Manager without changing this value. See
  # the Home Manager release notes for a list of state version
  # changes in each release.
  home.stateVersion = "25.11";
}