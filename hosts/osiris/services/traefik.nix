{
  config,
  lib,
  ...
}:
let
  cfg = config.services.traefik;
in
{
  # Imports cannot be conditional.
  imports = [ ./traefik-rules ];

  # Merging uncoditional and conditional config requires merge, since implicit
  # config cannot coexist with explicit config (needed for mkIf).
  config = lib.mkMerge [
    {
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
              proxyProtocol.trustedIPs = [ config.vpsPrivateIp ]; # VPS TS IP
            };
            websecure = {
              address = ":443";
              http3 = true;
              forwardedHeaders.trustedIPs = [
                "10.0.0.0/8"
                "100.64.0.0/10"
              ];
              proxyProtocol.trustedIPs = [ config.vpsPrivateIp ];
              http.tls = {
                certResolver = "cfResolver";
                domains = [
                  {
                    main = "${config.publicDomain}";
                    sans = [
                      "*.${config.publicDomain}"
                      "*.${config.privateDomain}"
                    ];
                  }
                ];
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

          # Docker Provider
          providers.docker = {
            endpoint = "unix:///var/run/docker.sock";
            exposedByDefault = false;
            network = "traefik_proxy";
          };

          # Let's Encrypt (Cloudflare)
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

          # Metrics & Logging
          metrics.prometheus = {
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
            bufferingSize = 100;
            filters.statusCodes = [
              "204-299"
              "400-499"
              "500-599"
            ];
            fields.headers.defaultMode = "drop";
            fields.headers.names = {
              User-Agent = "keep";
              Referer = "keep";
            };
          };
        };

        dynamicConfigOptions.http.routers = {
          traefik-dashboard = {
            rule = "Host(`traefik.${config.privateDomain}`)";
            entryPoints = [ "websecure" ];
            service = "api@internal";
            middlewares = [ "chain-authentik" ];
          };
        };
      };

    }

    (lib.mkIf cfg.enable {
      users.users.traefik.extraGroups = [ "docker" ];

      systemd.services.traefik = {
        requires = [ "docker.service" ];
        after = [ "docker.service" ];
        serviceConfig = {
          EnvironmentFile = config.sops.templates."traefik_cloudflare.env".path;
        };
      };

      sops.templates."traefik_cloudflare.env" = {
        content = ''
          CF_DNS_API_TOKEN=${config.sops.placeholder.cf_dns_api_token}
          CF_ZONE_API_TOKEN=${config.sops.placeholder.cf_zone_api_token}
          CLOUDFARE_EMAIL=${config.sops.placeholder.cloudflare_email}
        '';
      };

      sops.secrets.cf_dns_api_token = {
        key = "cf/dns_api_token";
        mode = "0440";
        owner = config.users.users.traefik.name;
        group = config.users.users.traefik.group;
        restartUnits = [ "traefik.service" ];
      };
      sops.secrets.cf_zone_api_token = {
        key = "cf/zone_api_token";
        mode = "0440";
        owner = config.users.users.traefik.name;
        group = config.users.users.traefik.group;
        restartUnits = [ "traefik.service" ];
      };
      sops.secrets.cloudflare_email = {
        key = "cf/email";
        mode = "0440";
        owner = config.users.users.traefik.name;
        group = config.users.users.traefik.group;
        restartUnits = [ "traefik.service" ];
      };
    })
  ];
}
