{ config, lib, ... }:
let
  inherit (lib.attrsets) mapAttrs' nameValuePair;
  inherit (lib.modules) mkMerge;
  inherit (lib.options) mkOption;
  inherit (lib.types) attrsOf listOf str;
  allowlistChains = config.mkAllowlistChain;
in
{
  options.mkAllowlistChain = mkOption {
    type = attrsOf (listOf str);
    default = { };
    description = ''
      IP ranges for generated Traefik allowlist chains. Each entry creates
      `middlewares-<name>-allowlist` and `chain-<name>` middlewares.
    '';
  };

  config = {
    services.traefik.dynamicConfigOptions.http.middlewares = mkMerge [
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

      (mapAttrs' (
        name: sourceRange:
        nameValuePair "middlewares-${name}-allowlist" {
          ipAllowList = { inherit sourceRange; };
        }
      ) allowlistChains)

      (mapAttrs' (
        name: _:
        nameValuePair "chain-${name}" {
          chain.middlewares = [
            "middlewares-${name}-allowlist"
            "middlewares-secure-headers"
          ];
        }
      ) allowlistChains)
    ];

    mkAllowlistChain.tailscale = [
      "100.64.0.0/10"
      "fd7a:115c:a1e0::/48"
      "127.0.0.1/32"
      "::1/128"
    ];
  };
}
