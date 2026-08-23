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

  # Never generate remediation decisions for authenticated tailnet peers.
  services.crowdsec.localConfig.parsers.s02Enrich = [
    {
      name = "local/tailnet-whitelist";
      description = "Whitelist authenticated tailnet traffic";
      whitelist = {
        reason = "Tailnet peer";
        cidr = [
          "100.64.0.0/10"
          "fd7a:115c:a1e0::/48"
        ];
      };
    }
  ];

}
