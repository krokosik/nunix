{
  config,
  inputs,
  ...
}:
{
  imports = [ inputs.dms.nixosModules.dank-material-shell ];

  programs.dank-material-shell.enable = true;

  services.displayManager.dms-greeter = {
    enable = true;
    compositor.name = "hyprland";
    configHome = "/home/${config.username}";
  };
}
