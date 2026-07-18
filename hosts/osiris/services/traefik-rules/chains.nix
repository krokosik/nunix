{ ... }:
{
  services.traefik.dynamicConfigOptions.http.middlewares = {
    chain-authentik.chain.middlewares = [
      "middlewares-crowdsec-bouncer"
      "middlewares-geoblock"
      "middlewares-rate-limit"
      "middlewares-secure-headers"
      "middlewares-authentik"
    ];

    chain-lapi.chain.middlewares = [
      "middlewares-lapi-allowlist"
      "middlewares-secure-headers"
    ];

    chain-no-auth.chain.middlewares = [
      "middlewares-crowdsec-bouncer"
      "middlewares-geoblock"
      "middlewares-rate-limit"
      "middlewares-secure-headers"
    ];
  };
}
