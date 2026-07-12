{ config,... }:
{
  services.traefik.dynamicConfigOptions.http.middlewares = {
    
    middlewares-lapi-allowlist.ipAllowList.sourceRange = [
      "${config.vpsPrivateIp}/32" # anubis tailscale
      "${config.homeserverPrivateIp}/32" # osiris tailscale
      "192.168.91.0/24" # local network
    ];
  };
}