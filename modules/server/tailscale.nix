{ config, inputs, ... }:
let
  secretspath = builtins.toString inputs.my-secrets;
in
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
    sopsFile = "${secretspath}/server/secrets.yaml";
    owner = "root";
    mode = "0400";
  };
}