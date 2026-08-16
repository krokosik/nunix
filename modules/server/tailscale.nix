{
  config,
  inputs,
  ...
}:
{
  imports = [ ../common/tailscale.nix ];

  services.tailscale = {
    authKeyFile = config.sops.secrets.tailscale_server_auth_key.path;
    extraUpFlags = [
      "--ssh"
      "--advertise-tags=tag:server"
    ];
  };
  sops.secrets.tailscale_server_auth_key = {
    sopsFile = "${inputs.my-secrets}/server/secrets.yaml";
    owner = "root";
    mode = "0400";
  };

}
