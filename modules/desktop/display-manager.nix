{
  config,
  ...
}:
{
  services.displayManager = {
    plasma-login-manager.enable = true;
    autoLogin = {
      enable = true;
      user = config.username;
    };
  };
}