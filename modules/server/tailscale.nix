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

  networking.firewall.extraInputRules = /* nftables */ ''
    ip saddr 172.16.0.0/12 udp dport 53 accept
    ip saddr 172.16.0.0/12 tcp dport 53 accept
    ip saddr 192.168.90.0/24 udp dport 53 accept
    ip saddr 192.168.90.0/24 tcp dport 53 accept
    ip saddr 192.168.91.0/24 udp dport 53 accept
    ip saddr 192.168.91.0/24 tcp dport 53 accept
  '';
}
