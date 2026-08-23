{ config, lib, ... }:
let
  allowlistChains = config.mkAllowlistChain;
in
{
  options.mkAllowlistChain = lib.mkOption {
    type = lib.types.attrsOf (lib.types.listOf lib.types.str);
    default = { };
    description = ''
      IP ranges for generated Traefik allowlist chains. Each entry creates
      `middlewares-<name>-allowlist` and `chain-<name>` middlewares.
    '';
  };

  mkAllowlistChain.tailscale = [
    "100.64.0.0/10"
    "fd7a:115c:a1e0::/48"
    "127.0.0.1/32"
    "::1/128"
  ];

  config.services.traefik.dynamicConfigOptions.http.middlewares = lib.mkMerge [
    {
      chain-authentik.chain.middlewares = [
        "middlewares-crowdsec-bouncer"
        "middlewares-geoblock"
        "middlewares-rate-limit"
        "middlewares-secure-headers"
        "middlewares-authentik"
      ];

      chain-no-auth.chain.middlewares = [
        "middlewares-crowdsec-bouncer"
        "middlewares-geoblock"
        "middlewares-rate-limit"
        "middlewares-secure-headers"
      ];
    }

    (lib.mapAttrs' (
      name: sourceRange:
      lib.nameValuePair "middlewares-${name}-allowlist" {
        ipAllowList = { inherit sourceRange; };
      }
    ) allowlistChains)

    (lib.mapAttrs' (
      name: _:
      lib.nameValuePair "chain-${name}" {
        chain.middlewares = [
          "middlewares-${name}-allowlist"
          "middlewares-secure-headers"
        ];
      }
    ) allowlistChains)
  ];
}
