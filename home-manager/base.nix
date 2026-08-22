{
  osConfig,
  inputs,
  ...
}:
{
  imports = [
    ./common
  ];

  home.username = osConfig.username;
  home.homeDirectory = "/home/${osConfig.username}";
  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;

  sops = {
    age.keyFile = osConfig.sops.secrets.home_manager_age_key.path;
    defaultSopsFile = "${inputs.my-secrets}/common/home.yaml";
  };

  # This value determines the Home Manager release that your
  # configuration is compatible with. This helps avoid breakage
  # when a new Home Manager release introduces backwards
  # incompatible changes.
  #
  # You can update Home Manager without changing this value. See
  # the Home Manager release notes for a list of state version
  # changes in each release.
  home.stateVersion = "26.05";
}
