{ config, ... }:
{
  services.tailscale = {
    enable = true;
    authKeyFile = config.sops.secrets.tailscale_server_auth_key.path;
    extraUpFlags = [
      "--ssh"
      "--advertise-tags=tag:server"
    ];
  };
  sops.secrets.tailscale_server_auth_key = {
    owner = "root";
    mode = "0400";
  };
}