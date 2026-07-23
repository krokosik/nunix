# Authentik — native systemd units via authentik-nix.
# Owns the `myAuthentik` option namespace that app modules contribute to:
#   * extraBlueprints   — blueprint dirs merged into authentik's blueprints_dir
#   * forwardAuthApps   — apps gated by the embedded outpost via Traefik
#                         forward_auth (chain-authentik middleware)
#   * oidcApps          — apps that speak OIDC against authentik directly
#
# `oidcApps` also handles boot-time HTTP readiness: each app's
# `appRestartUnit` is pulled `After=authentik-ready.service` so apps
# that fetch the OIDC discovery URL once at startup don't race
# authentik's Django worker and 502.
#
# Forward-auth specifics: the embedded outpost has a single global
# `providers` list. To avoid two blueprints clobbering it, this module
# renders one merged blueprint per host that owns every registered
# forward-auth app's provider/application/policy-binding *and* the
# outpost's providers list, then contributes the dir via
# `myAuthentik.extraBlueprints`.
#
# OIDC specifics: each registered OIDC app gets one sops secret pair
# (oidc_client_id / oidc_client_secret unless `publicClient`).
# Worker-side env vars (consumed by `!Env` in the per-app blueprint)
# are merged into a single env file stacked once onto authentik's
# units, regardless of how many OIDC apps are registered. Whether the
# app gets its own env file too depends on how it consumes credentials.
#
# Secrets in blueprints are passed via `!Env VAR_NAME`; the `VAR_NAME`
# is rendered into the systemd EnvironmentFile from sops, so the
# secret never lands in /nix/store.
{
  inputs,
  config,
  lib,
  pkgs,
  ...
}:
let
  authentikPort = 9000;
  restartAuthentik = [
    "authentik.service"
    "authentik-worker.service"
    "authentik-migrate.service"
  ];

  fwApps = config.myAuthentik.forwardAuthApps;
  fwAppNames = lib.attrNames fwApps;

  inherit (config.myAuthentik) oidcApps;

  # One YAML entry block per forward-auth app: provider, application,
  # policy binding. `id:` anchors are used inside this same blueprint
  # by `!KeyOf` so the application can reference its own provider
  # without a managed-name lookup.
  perFwAppEntries = name: app: ''
    - model: authentik_providers_proxy.proxyprovider
      id: prov-${name}
      identifiers:
        name: ${name}
      attrs:
        mode: forward_single
        external_host: https://${app.host}
        authentication_flow: !Find [authentik_flows.flow, [slug, default-authentication-flow]]
        authorization_flow: !Find [authentik_flows.flow, [slug, default-provider-authorization-implicit-consent]]
        invalidation_flow: !Find [authentik_flows.flow, [slug, default-provider-invalidation-flow]]

    - model: authentik_core.application
      id: app-${name}
      identifiers:
        slug: ${name}
      attrs:
        name: ${app.displayName}
        provider: !KeyOf prov-${name}
        group: ${app.authentikGroup}
        open_in_new_tab: true
        meta_launch_url: https://${app.host}
        meta_icon: ${app.iconUrl}
        policy_engine_mode: all

    - model: authentik_policies.policybinding
      identifiers:
        target: !KeyOf app-${name}
        order: 0
      attrs:
        group: !Find [authentik_core.group, [name, ${app.authentikGroup}]]
        enabled: true'';

  # The separator must match the column the first item lands at after
  # the indented-string strip. `${outpostProviders}` sits at column 6,
  # so subsequent items need six leading spaces to share that column.
  outpostProviders = lib.concatMapStringsSep "\n      " (
    n: "- !Find [authentik_providers_proxy.proxyprovider, [name, ${n}]]"
  ) fwAppNames;

  # `authentik_host` is the base URL the outpost uses to reach the
  # authentik server; `authentik_host_browser` is the base URL the
  # outpost emits in 302 Location headers. With both unset, the
  # outpost falls back to its bind address (http://0.0.0.0:9000),
  # which a browser can't resolve. Encoding both here makes
  # forward-auth deterministic across hosts.
  outpostEntry = ''
    - model: authentik_outposts.outpost
      identifiers:
        name: authentik Embedded Outpost
      attrs:
        type: proxy
        providers:
          ${outpostProviders}
        config:
          authentik_host: https://authentik.${config.publicDomain}
          authentik_host_browser: https://authentik.${config.publicDomain}'';

  fwBlueprintContent = ''
    version: 1
    metadata:
      name: forward-auth-apps
    entries:
    ${lib.concatStringsSep "\n\n" ((lib.mapAttrsToList perFwAppEntries fwApps) ++ [ outpostEntry ])}
  '';

  fwBlueprintDir = pkgs.writeTextDir "forward-auth-apps.yaml" fwBlueprintContent;

  # Pre-render an OIDC app's blueprint dir: copy each *.yaml in and
  # substitute `@serverDomain@` → `config.publicDomain`. Per-contributor
  # substitution avoids a sed pass over the final merged dir that would
  # mangle any YAML value containing the literal string for an
  # unrelated purpose. `fwBlueprintDir` sidesteps the placeholder
  # entirely by interpolating the domain via Nix strings; any new
  # blueprint-contribution path must do one or the other.
  renderedBlueprintDir =
    name: src:
    pkgs.runCommandLocal "${name}-blueprints-rendered" { } ''
      mkdir $out
      cp -L ${src}/*.yaml $out/
      chmod -R u+w $out
      substituteInPlace $out/*.yaml \
        --replace-quiet '@serverDomain@' '${config.publicDomain}'
    '';

  # Restart units for an app's OIDC sops secret. Always bounces
  # authentik (so the worker sees the new placeholder when the
  # blueprint is re-applied); also bounces the app's own service
  # iff the app reads creds from its env file.
  oidcSecretRestartUnits =
    app: restartAuthentik ++ lib.optionals app.clientCredsInAppEnv app.appRestartUnit;

  mkOidcSecret = _appName: app: {
    restartUnits = oidcSecretRestartUnits app;
  };

  # Worker-side env line for one OIDC app. Uppercased app name keeps
  # the existing `<APP>_OIDC_CLIENT_*` convention every blueprint
  # references via `!Env`.
  oidcWorkerEnvLines =
    appName: app:
    let
      upper = lib.toUpper (lib.replaceStrings [ "-" ] [ "_" ] appName);
      idLine = "${upper}_OIDC_CLIENT_ID=${config.sops.placeholder."${appName}/oidc_client_id"}";
      secretLine = "${upper}_OIDC_CLIENT_SECRET=${
        config.sops.placeholder."${appName}/oidc_client_secret"
      }";
    in
    if app.publicClient then idLine + "\n" else idLine + "\n" + secretLine + "\n";

  # Per-app env file content. Combines configurable client-id/secret
  # env vars (when `clientCredsInAppEnv`) with whatever extra lines
  # the app needs (db password, secret_key, inline-JSON env vars).
  oidcAppEnvContent =
    appName: app:
    let
      idLine = "${app.clientIdVar}=${config.sops.placeholder."${appName}/oidc_client_id"}";
      secretLine = "${app.clientSecretVar}=${config.sops.placeholder."${appName}/oidc_client_secret"}";
      credsBlock =
        if !app.clientCredsInAppEnv then
          ""
        else if app.publicClient then
          idLine + "\n"
        else
          idLine + "\n" + secretLine + "\n";
    in
    credsBlock + app.extraEnvLines;

  oidcWorkerEnvContent = lib.concatStrings (lib.mapAttrsToList oidcWorkerEnvLines oidcApps);

  # Stack upstream blueprints + every contributed dir into a single
  # real-file directory. Copy with `-L` to dereference: authentik's
  # `retrieve_file` calls `Path(...).resolve()` on every blueprint and
  # rejects anything that resolves outside `blueprints_dir`, so
  # `symlinkJoin` (top-level entries are symlinks back to source store
  # paths) makes every apply fail with "Invalid blueprint path".
  mergedBlueprints = pkgs.runCommandLocal "authentik-blueprints-merged" { } ''
    mkdir -p $out
    cp -rL ${config.services.authentik.authentikComponents.staticWorkdirDeps}/blueprints/. $out/
    ${lib.concatMapStringsSep "\n" (p: "cp -rL ${p}/. $out/") config.myAuthentik.extraBlueprints}
    chmod -R u+w $out
  '';
in
{
  imports = [ inputs.authentik-nix.nixosModules.default ];

  options.myAuthentik = {
    extraBlueprints = lib.mkOption {
      type = lib.types.listOf lib.types.path;
      default = [ ];
      description = ''
        Extra blueprint directories or files to merge into authentik's
        blueprints_dir alongside the bundled defaults. Each entry is a
        path containing one or more *.yaml blueprint files. Other app
        modules can append their own blueprints here so each app stays
        self-contained.
      '';
    };

    forwardAuthApps = lib.mkOption {
      default = { };
      description = ''
        Apps gated by authentik forward-auth via Traefik (chain-authentik
        middleware). Each entry generates an authentik proxy provider +
        application + policy binding (default group: users),
        plus the embedded outpost's `providers` list entry. One
        blueprint owns the outpost's `providers` list, so every
        forward-auth app on the host must register through this option
        rather than emitting its own outpost block. The Traefik router
        + middleware chain is configured in each app's own service
        module via `myTraefikServices.<name>`.
      '';
      type = lib.types.attrsOf (
        lib.types.submodule (
          { name, ... }:
          {
            options = {
              host = lib.mkOption {
                type = lib.types.str;
                default = "${name}.${config.publicDomain}";
                description = "External hostname Traefik matches and authentik enforces.";
              };
              displayName = lib.mkOption {
                type = lib.types.str;
                description = "Human-facing app name (authentik tile).";
              };
              iconUrl = lib.mkOption {
                type = lib.types.str;
                default = "https://raw.githubusercontent.com/homarr-labs/dashboard-icons/main/png/${name}.png";
                description = "Icon URL used on the authentik application tile.";
              };
              authentikGroup = lib.mkOption {
                type = lib.types.str;
                default = "users";
                description = ''
                  Authentik group whose members can access this app via
                  the policy binding. Defaults to users;
                '';
              };
            };
          }
        )
      );
    };

    oidcApps = lib.mkOption {
      default = { };
      description = ''
        Apps that authenticate against Authentik via OIDC directly
        (the app speaks OIDC; we do not use the embedded outpost).
        Each entry generates the sops secret pair, contributes a
        blueprint dir, and stacks a single merged worker env file
        onto Authentik so blueprint `!Env` placeholders resolve.

        Apps that read OIDC creds from env vars also get a per-app
        env file the upstream image consumes. Apps that read OIDC
        creds from their own database (e.g. audiobookshelf, kavita,
        seerr) opt out by setting `clientCredsInAppEnv = false`.
      '';
      type = lib.types.attrsOf (
        lib.types.submodule (
          { name, ... }:
          {
            options = {
              blueprintsDir = lib.mkOption {
                type = lib.types.path;
                description = ''
                  Path to a directory of *.yaml blueprint files for
                  this app. The dir is contributed via
                  `myAuthentik.extraBlueprints` and merged into
                  authentik's blueprints_dir.
                '';
              };
              appRestartUnit = lib.mkOption {
                type = lib.types.listOf lib.types.str;
                default = [ ];
                description = ''
                  Systemd units to restart when the per-app env
                  file changes. Required (non-empty) when
                  `clientCredsInAppEnv` is true or `extraEnvLines`
                  is non-empty. Leave as the empty default for
                  apps with no per-app env file. Pass every unit that
                  consumes the env file (e.g. paperless-ngx with
                  paperless-{web,scheduler,task-queue,consumer}).
                '';
              };
              publicClient = lib.mkOption {
                type = lib.types.bool;
                default = false;
                description = ''
                  True for OIDC public clients (PKCE, no
                  client_secret). When true, only oidc_client_id
                  is provisioned; client_secret is omitted from
                  both sops and the env files.
                '';
              };
              clientCredsInAppEnv = lib.mkOption {
                type = lib.types.bool;
                default = true;
                description = ''
                  Whether the per-app env file should include the
                  OIDC client_id (and client_secret unless
                  `publicClient`). Set to false when the app reads
                  these from its own database/UI rather than env.
                '';
              };
              envFileName = lib.mkOption {
                type = lib.types.str;
                default = "${name}.env";
                description = ''
                  Name of the sops template the per-app env file is
                  registered under. Reference it in the upstream
                  service via `config.sops.templates."<name>".path`.
                '';
              };
              clientIdVar = lib.mkOption {
                type = lib.types.str;
                default = "OIDC_CLIENT_ID";
                description = "Env var name the upstream image reads for the OIDC client id.";
              };
              clientSecretVar = lib.mkOption {
                type = lib.types.str;
                default = "OIDC_CLIENT_SECRET";
                description = "Env var name the upstream image reads for the OIDC client secret.";
              };
              extraEnvLines = lib.mkOption {
                type = lib.types.lines;
                default = "";
                description = ''
                  Extra `KEY=value` lines appended to the per-app
                  env file. Use this for db passwords, secret keys,
                  or inline-JSON env vars whose values come from
                  other sops placeholders. Whatever placeholders
                  this string references must be declared via
                  `extraSecrets`.
                '';
              };
              extraSecrets = lib.mkOption {
                type = lib.types.attrsOf lib.types.attrs;
                default = { };
                description = ''
                  Additional sops secret declarations merged into
                  sops.secrets. Use this for db passwords, signing
                  keys, etc. that the per-app env file references
                  via `extraEnvLines`.
                '';
              };
              displayName = lib.mkOption {
                type = lib.types.str;
                default = name;
                description = ''
                  Human-facing app name (authentik tile). Defaults
                  to the attribute name.
                '';
              };
            };
          }
        )
      );
    };
  };

  config = lib.mkMerge [
    {
      sops.secrets = {
        authentik_secret_key.key = "authentik/secret_key";
        authentik_bootstrap_email.key = "authentik/bootstrap_email";
        authentik_bootstrap_password.key = "authentik/bootstrap_password";
        authentik_bootstrap_token.key = "authentik/bootstrap_token";
      };

      sops.templates."authentik.env" = {
        content = ''
          AUTHENTIK_SECRET_KEY=${config.sops.placeholder.authentik_secret_key}
          AUTHENTIK_BOOTSTRAP_EMAIL=${config.sops.placeholder.authentik_bootstrap_email}
          AUTHENTIK_BOOTSTRAP_PASSWORD=${config.sops.placeholder.authentik_bootstrap_password}
          AUTHENTIK_BOOTSTRAP_TOKEN=${config.sops.placeholder.authentik_bootstrap_token}
          AUTHENTIK_EMAIL__HOST=127.0.0.1
          AUTHENTIK_EMAIL__PORT=2500
          AUTHENTIK_EMAIL__FROM=${config.networking.hostName}@${config.publicDomain}
          AUTHENTIK_EMAIL__USE_TLS=false
          AUTHENTIK_EMAIL__USE_SSL=false
          AUTHENTIK_EMAIL__TIMEOUT=10
        '';
        restartUnits = restartAuthentik;
      };

      services.authentik = {
        enable = true;
        environmentFile = config.sops.templates."authentik.env".path;
        settings = {
          disable_startup_analytics = true;
          avatars = "initials";
          blueprints_dir = "${mergedBlueprints}";
        };
      };

      myTraefikServices.authentik = {
        port = authentikPort;
        public = true;
        chain = [ "chain-no-auth" ];
      };

      # Heal DynamicUser+StateDirectory idmap and rsynced appdata ownership.
      systemd.services.authentik-migrate.serviceConfig.ExecStartPre = [
        "+${pkgs.writeShellScript "authentik-state-chown" ''
          ${pkgs.coreutils}/bin/chown -R authentik:authentik /var/lib/private/authentik
        ''}"
      ];

      # Real readiness boundary for the authentik stack. The three
      # native units are all Type=simple, so systemd considers them
      # "active" long before Django answers HTTP. /-/health/ready/
      # returns 200 only after Django can answer, so probing it gives
      # dependents a real readiness gate. RemainAfterExit+PartOf
      # propagates authentik's stop/restart here so the gate is torn
      # down with authentik and re-runs its poll before dependents
      # that restart in the same transaction proceed.
      systemd.services.authentik-ready = {
        description = "Wait for authentik to serve 200 on /-/health/ready/";
        after = [
          "authentik.service"
          "authentik-worker.service"
        ];
        wants = [
          "authentik.service"
          "authentik-worker.service"
        ];
        partOf = [
          "authentik.service"
          "authentik-worker.service"
        ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          TimeoutStartSec = "180s";
        };
        script = ''
          until ${pkgs.curl}/bin/curl -fsS -o /dev/null \
            -m 3 http://localhost:${toString authentikPort}/-/health/ready/; do
            sleep 2
          done
        '';
      };
    }

    (lib.mkIf (fwApps != { }) {
      myAuthentik.extraBlueprints = [ fwBlueprintDir ];
    })

    (lib.mkIf (oidcApps != { }) {
      # OIDC client_id/_secret per app, plus any extras the app declares.
      sops.secrets =
        (lib.foldl' lib.mergeAttrs { } (
          lib.mapAttrsToList (
            appName: app:
            {
              "${appName}/oidc_client_id" = mkOidcSecret appName app;
            }
            // lib.optionalAttrs (!app.publicClient) {
              "${appName}/oidc_client_secret" = mkOidcSecret appName app;
            }
          ) oidcApps
        ))
        // (lib.foldl' lib.mergeAttrs { } (lib.mapAttrsToList (_: app: app.extraSecrets) oidcApps));

      # Per-app env file. Always declared (lazy) — apps that don't
      # need it (DB/UI-configured) end up with an empty file that
      # nothing references. Filtering eagerly here would force
      # `extraEnvLines` and create a cycle through sops.placeholder.
      sops.templates =
        (lib.mapAttrs' (
          appName: app:
          lib.nameValuePair app.envFileName {
            content = oidcAppEnvContent appName app;
            restartUnits = app.appRestartUnit;
          }
        ) oidcApps)
        // {
          # ONE merged worker env file containing <APP>_OIDC_CLIENT_*
          # vars for every registered OIDC app — stacked once onto
          # authentik's units instead of N times.
          "authentik-oidc-apps.env" = {
            content = oidcWorkerEnvContent;
            restartUnits = restartAuthentik;
          };
        };

      systemd.services = lib.mkMerge [
        {
          authentik.serviceConfig.EnvironmentFile = [
            config.sops.templates."authentik-oidc-apps.env".path
          ];
          authentik-worker.serviceConfig.EnvironmentFile = [
            config.sops.templates."authentik-oidc-apps.env".path
          ];
          authentik-migrate.serviceConfig.EnvironmentFile = [
            config.sops.templates."authentik-oidc-apps.env".path
          ];
        }
        # Inject After=authentik-ready.service on every OIDC app's
        # restart units so apps that probe the OIDC discovery URL at
        # startup don't race the Django worker. Apps with empty
        # appRestartUnit (DB/UI-configured) end up no-op'd through
        # genAttrs and are immune to the race anyway.
        (lib.mkMerge (
          lib.mapAttrsToList (
            _appName: app:
            lib.genAttrs (map (lib.removeSuffix ".service") app.appRestartUnit) (_: {
              after = [ "authentik-ready.service" ];
              wants = [ "authentik-ready.service" ];
            })
          ) oidcApps
        ))
      ];

      myAuthentik.extraBlueprints = lib.mapAttrsToList (
        appName: app: renderedBlueprintDir appName app.blueprintsDir
      ) oidcApps;
    })
  ];
}
