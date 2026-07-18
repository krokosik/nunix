{ config, ... }:
{
  security.sudo.extraRules = [
    {
      users = [ config.username ];
      commands = [
        {
          command = "ALL";
          options = [ "NOPASSWD" ];
        }
      ];
    }
  ];
}
