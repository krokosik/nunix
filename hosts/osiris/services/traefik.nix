{
  config,
  lib,
  ...
}:
let
  inherit (lib.attrsets) mapAttrs mapAttrs' nameValuePair;
  inherit (lib.lists) singleton;
  inherit (lib.modules) mkForce mkIf mkMerge;
  inherit (lib.options) mkOption;
  inherit (lib.types)
    attrsOf
    bool
    listOf
    port
    str
    submodule
    ;
  cfg = config.services.traefik;
in
{
  # Imports cannot be conditional.
  imports = [
    ./traefik-rules
    ./traefik-logs.nix
  ];

  options.mkTraefikServices = mkOption {
    type = attrsOf (
      let
        outerConfig = config;
      in
      submodule (
        { name, config, ... }:
        {
          options = {
            port = mkOption {
              type = port;
              default = null;
              description = ''
                Host port to bind the traefik service to.
              '';
            };
            host = mkOption {
              type = str;
              default = "localhost";
              description = ''
                Host address to where the traefik service is bound.
              '';
            };
            subdomain = mkOption {
              type = str;
              default = name;
              description = ''
                Subdomain to bind the traefik service to. Defaults to the attribute name.
              '';
            };
            public = mkOption {
              type = bool;
              default = false;
              description = ''
                Whether the traefik service is public-facing (routed via public domain) or internal-only (binds to private domain). Defaults to false (internal-only).
              '';
            };
            chain = mkOption {
              type = listOf str;
              default = singleton "chain-authentik";
              description = ''
                Specify a list of middlewares to apply to the traefik router. Defaults to [ "chain-authentik" ].
              '';
            };
            fullHostname = mkOption {
              type = str;
              readOnly = true;
              description = ''
                Full hostname of the traefik service. Automatically derived from the subdomain and public/private domain options.
              '';
            };
          };

          config = {
            fullHostname = "https://${config.subdomain}.${
              if config.public then outerConfig.publicDomain else outerConfig.privateDomain
            }";
          };
        }
      )
    );
    default = { };
    description = ''
      Traefik service configuration. Each entry creates a traefik router/service pair. The domain
      is automatically derived from the attribute name and the public/private domain options and
      always bound to websecure: https://<name>.<publicDomain|privateDomain> -> http://<host>:<port>
    '';
  };

  # Merging uncoditional and conditional config requires merge, since implicit
  # config cannot coexist with explicit config (needed for mkIf).
  config = mkMerge [
    {
      mkObservabilityServices.traefik = {
        units = singleton config.systemd.services.traefik.name;
        metrics.url = "http://127.0.0.1:8000/metrics";
      };

      mkObservability = {
        repeatedErrorUnits = mkIf cfg.enable config.mkObservabilityServices.traefik.units;

        inactiveAlertUnits = mkIf cfg.enable config.mkObservabilityServices.traefik.units;
      };

      services.traefik = {
        enable = true;

        staticConfigOptions = {
          global = {
            checkNewVersion = false;
            sendAnonymousUsage = false;
          };

          # 2. Entrypoints & Proxy Protocol
          entryPoints = {
            web = {
              address = ":80";
              http.redirections.entryPoint = {
                to = "websecure";
                scheme = "https";
                permanent = true;
              };
              forwardedHeaders.trustedIPs = [
                "10.0.0.0/8"
                "100.64.0.0/10"
              ]; # Local & Tailscale
              proxyProtocol.trustedIPs = [
                config.tailscaleAddresses.anubis.ipv4
                config.mkIngressWireguard.edgeIPv4
              ];
            };
            websecure = {
              address = ":443";
              http3 = true;
              forwardedHeaders.trustedIPs = [
                "10.0.0.0/8"
                "100.64.0.0/10"
              ];
              proxyProtocol.trustedIPs = [
                config.tailscaleAddresses.anubis.ipv4
                config.mkIngressWireguard.edgeIPv4
              ];
              http.tls = {
                certResolver = "cfResolver";
                domains = singleton {
                  main = "${config.publicDomain}";
                  sans = [
                    "*.${config.publicDomain}"
                    "*.${config.privateDomain}"
                  ];
                };
              };
            };
            traefik = {
              address = ":8000";
            };
          };

          api = {
            dashboard = true;
            insecure = false;
          };

          # DOCKER PROVIDER
          providers.docker = {
            endpoint = "unix:///var/run/docker.sock";
            exposedByDefault = false;
            network = "traefik_proxy";
          };

          # LET'S ENCRYPT (CLOUDFLARE)
          certificatesResolvers.cfResolver.acme = {
            dnsChallenge = {
              provider = "cloudflare";
              resolvers = [
                "1.1.1.1:53"
                "1.0.0.1:53"
              ];
              propagation = {
                delayBeforeChecks = 120;
                disableChecks = true;
              };
            };
          };

          # METRICS & LOGGING
          metrics.prometheus = {
            entryPoint = "traefik";
            addEntryPointsLabels = true;
            addRoutersLabels = true;
            addServicesLabels = true;
            buckets = [
              0.05
              0.1
              0.3
              1.2
              5.0
            ];
          };

          log = {
            level = "INFO";
          };
          accessLog = {
            format = "json";
            bufferingSize = 100;
            fields.headers = {
              defaultMode = "drop";
              names = {
                User-Agent = "keep";
                Referer = "keep";
              };
            };
          };
        };

        dynamicConfigOptions.http = {
          services = mapAttrs' (
            name: svc:
            nameValuePair "${name}-svc" {
              loadBalancer.servers = singleton { url = "http://${svc.host}:${toString svc.port}"; };
            }
          ) config.mkTraefikServices;

          routers =
            (mapAttrs (name: svc: {
              rule = "Host(`${svc.subdomain}.${
                if svc.public then config.publicDomain else config.privateDomain
              }`)";
              entryPoints = singleton "websecure";
              service = "${name}-svc";
              middlewares = svc.chain;
            }) config.mkTraefikServices)
            // {
              traefik-dashboard = {
                rule = "Host(`traefik.${config.privateDomain}`)";
                entryPoints = singleton "websecure";
                service = "api@internal";
                middlewares = singleton "chain-authentik";
              };
            };
        };
      };

    }

    (mkIf cfg.enable {
      users.users.traefik.extraGroups = singleton "docker";

      systemd.services.traefik = {
        requires = singleton "docker.service";
        wants = singleton "network-online.target";
        after = [
          "docker.service"
          "network-online.target"
          "systemd-resolved.service"
        ];
        startLimitIntervalSec = mkForce 0;
        serviceConfig = {
          EnvironmentFile = config.sops.templates."traefik_cloudflare.env".path;
          Restart = mkForce "always";
          RestartSec = "30s";
        };
      };

      sops = {
        secrets = {
          cf_dns_api_token.key = "cf/dns_api_token";
          cf_zone_api_token.key = "cf/zone_api_token";
          cf_email.key = "cf/email";
        };
        templates."traefik_cloudflare.env" = {
          content = /* bash */ ''
            CF_DNS_API_TOKEN=${config.sops.placeholder.cf_dns_api_token}
            CF_ZONE_API_TOKEN=${config.sops.placeholder.cf_zone_api_token}
            CLOUDFARE_EMAIL=${config.sops.placeholder.cf_email}
          '';

          owner = config.users.users.traefik.name;
          restartUnits = singleton "traefik.service";
        };
      };

      mkAuthentik.forwardAuthApps.traefik = {
        displayName = "Traefik";
        host = "https://traefik.${config.privateDomain}";
      };
    })
  ];

}
