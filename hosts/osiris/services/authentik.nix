# Authentik — native systemd units via authentik-nix.
# Owns the `mkAuthentik` option namespace that app modules contribute to:
#   * extraBlueprints   — blueprint dirs merged into authentik's blueprints_dir
#   * forwardAuthApps   — apps gated by the embedded outpost via Traefik
#                         forward_auth (chain-authentik middleware)
#   * oidcApps          — apps that speak OIDC against authentik directly
#
# Forward-auth specifics: the embedded outpost has a single global
# `providers` list. To avoid two blueprints clobbering it, this module
# renders one merged blueprint per host that owns every registered
# forward-auth app's provider/application/policy-binding *and* the
# outpost's providers list, then contributes the dir via
# `mkAuthentik.extraBlueprints`.
#
# OIDC specifics: each registered app gets sops credentials and a
# generated provider/application/policy-binding blueprint. A merged
# Authentik-only env file supplies `!Env` without storing credentials
# in the Nix store. Consumers decide how to read the sops secrets.
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

  fwApps = config.mkAuthentik.forwardAuthApps;
  fwAppNames = lib.attrNames fwApps;

  inherit (config.mkAuthentik) oidcApps;
  credentialType = import ../../../lib/types/credential.nix;

  # Classification taxonomy — options below constrain `accessGroup` and
  # `displayGroup` to one of these strings. Together the two let lists
  # drive both the validation assertions and the rendered baseline group
  # entries that always ship with the forward-auth blueprint.

  # Access hierarchy (nested via `parents`): admins ⊃ family ⊃ friends ⊃ users.
  # Each tier inherits every permission granted to any junior tier.
  accessGroupNames = [
    "users"
    "friends"
    "family"
    "admins"
  ];

  # Display categories (flat, no nesting): used for the UI tile grouping
  # on the authentik application library page. Purely cosmetic — no
  # policy evaluation touches these groups.
  displayGroupNames = [
    "Infrastructure"
    "Arr"
    "Apps"
    "Finance"
  ];

  # Baseline group entries prepended to every generated blueprint. Using
  # `!KeyOf` anchors here means per-app entries in the same instance can
  # reference `grp-<name>` deterministically — authentik builds a DAG and
  # applies in dependency order, so the cross-instance race that bit us
  # (forward-auth-apps applied before the groups existed) can't recur.
  # `grp-` prefix keeps the anchor namespace clear of app `id:` anchors.
  groupsBaselineContent = ''
    version: 1
    metadata:
      name: groups-baseline
    entries:
      - model: authentik_core.group
        id: grp-users
        identifiers:
          name: users
        attrs:
          is_superuser: false
          parents: []

      - model: authentik_core.group
        id: grp-friends
        identifiers:
          name: friends
        attrs:
          is_superuser: false
          parents:
            - !KeyOf grp-users

      - model: authentik_core.group
        id: grp-family
        identifiers:
          name: family
        attrs:
          is_superuser: false
          parents:
            - !KeyOf grp-friends

      - model: authentik_core.group
        id: grp-admins
        identifiers:
          name: admins
        attrs:
          is_superuser: true
          parents:
            - !KeyOf grp-family'
  '';

  # Split out from `forward-auth-apps.yaml` because authentik's `!KeyOf`
  # is instance-scoped (`BlueprintImporter.__pk_map` is per instance,
  # not per blueprints_dir) — keeping groups in their own instance
  # means adding/removing apps doesn't churn the groups hash, and
  # groups exist before any app blueprint's `!Find` lookup fires.
  groupsBaselineDir = pkgs.writeTextDir "groups-baseline.yaml" groupsBaselineContent;

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
        group: ${app.displayGroup}
        open_in_new_tab: true
        meta_launch_url: https://${app.host}
        meta_icon: ${app.iconUrl}
        policy_engine_mode: all

    - model: authentik_policies.policybinding
      identifiers:
        target: !KeyOf app-${name}
        order: 0
      attrs:
        group: !Find [authentik_core.group, [name, ${app.accessGroup}]]
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

  # Quote user-provided YAML scalars, keeping URLs and names safe from
  # YAML punctuation and preventing a value from becoming a YAML tag.
  yamlString = value: lib.strings.toJSON value;

  oidcEnvName =
    name: kind: "AUTHENTIK_OIDC_${lib.toUpper (lib.replaceStrings [ "-" ] [ "_" ] name)}_${kind}";

  oidcBlueprintDir =
    name: app:
    let
      providerFields = lib.concatStringsSep "\n" (
        [ "      client_id: !Env ${oidcEnvName name "CLIENT_ID"}" ]
        ++ lib.optionals (!app.publicClient) [
          "      client_secret: !Env ${oidcEnvName name "CLIENT_SECRET"}"
        ]
        ++ [
          "      client_type: ${if app.publicClient then "public" else "confidential"}"
          "      grant_types: [authorization_code, refresh_token]"
          "      authorization_flow: !Find [authentik_flows.flow, [slug, default-provider-authorization-implicit-consent]]"
          "      invalidation_flow: !Find [authentik_flows.flow, [slug, default-provider-invalidation-flow]]"
          "      signing_key: !Find [authentik_crypto.certificatekeypair, [name, authentik Self-signed Certificate]]"
          "      issuer_mode: per_provider"
        ]
        ++ lib.optionals (app.logoutUri != null) [ "      logout_uri: ${yamlString app.logoutUri}" ]
        ++ [ "      redirect_uris:" ]
        ++ lib.concatMap (url: [
          "        - matching_mode: strict"
          "          redirect_uri_type: authorization"
          "          url: ${yamlString url}"
        ]) app.redirectUris
      );
    in
    pkgs.writeTextDir "oidc-${name}.yaml" /* yaml */ ''
      version: 1
      metadata:
        name: oidc-${name}
      entries:
        - model: authentik_providers_oauth2.oauth2provider
          id: prov-${name}
          identifiers:
            name: ${yamlString app.providerName}
          attrs:
      ${providerFields}

        - model: authentik_core.application
          id: app-${name}
          identifiers:
            slug: ${yamlString app.slug}
          attrs:
            name: ${yamlString app.displayName}
            provider: !KeyOf prov-${name}
            group: ${yamlString app.displayGroup}
            open_in_new_tab: true
            meta_launch_url: ${yamlString app.launchUrl}
            meta_icon: ${yamlString app.iconUrl}
            policy_engine_mode: all

        - model: authentik_policies.policybinding
          identifiers:
            target: !KeyOf app-${name}
            order: 0
          attrs:
            group: !Find [authentik_core.group, [name, ${app.accessGroup}]]
            enabled: true
    '';

  mkOidcSecret = credential: {
    key = if credential.key == null then credential.secretName else credential.key;
    inherit (credential) owner group mode;
    restartUnits = restartAuthentik;
  };

  # Worker-side env vars are internal to Authentik's blueprint importer.
  oidcWorkerEnvLines =
    appName: app:
    let
      idLine = "${oidcEnvName appName "CLIENT_ID"}=${
        config.sops.placeholder.${app.credentials.clientId.secretName}
      }";
      secretLine = "${oidcEnvName appName "CLIENT_SECRET"}=${
        config.sops.placeholder.${app.credentials.clientSecret.secretName}
      }";
    in
    idLine + "\n" + lib.optionalString (!app.publicClient) (secretLine + "\n");

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
    ${lib.concatMapStringsSep "\n" (p: "cp -rL ${p}/. $out/") config.mkAuthentik.extraBlueprints}
    chmod -R u+w $out
  '';
in
{
  imports = [ inputs.authentik-nix.nixosModules.default ];

  options.mkAuthentik = {
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
        application + policy binding, plus the embedded outpost's
        `providers` list entry. One blueprint owns the outpost's
        `providers` list, so every forward-auth app on the host must
        register through this option rather than emitting its own
        outpost block. The Traefik router + middleware chain is
        configured in each app's own service module via
        `mkTraefikServices.<name>`.

        Both `accessGroup` and `displayGroup` are validated against the
        fixed taxonomy declared in this module (see `accessGroupNames`
        / `displayGroupNames`) — typos fail the build via assertions.
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
              accessGroup = lib.mkOption {
                type = lib.types.enum accessGroupNames;
                default = "admins";
                description = ''
                  Access tier whose members can reach this app via its
                  policy binding. One of: users, friends, family,
                  admins. Defaults to admins (tightest); widen per app.
                  Inheritance is nested — admins ⊃ family ⊃ friends ⊃
                  users — so a senior tier's members automatically
                  satisfy the policy for any junior tier.
                '';
              };
              displayGroup = lib.mkOption {
                type = lib.types.enum displayGroupNames;
                default = "Infrastructure";
                description = ''
                  UI display category for the application library tile.
                  One of: Infrastructure, Arr, Apps, Finance. Defaults to
                  Infrastructure (admin/ops tools). Purely cosmetic —
                  no policy evaluation touches display groups.
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
        Each entry provisions sops credentials, generates the OAuth2
        provider, application and access-policy binding blueprint, and
        makes the credentials available to Authentik via `!Env`. The
        consuming service owns its own credential delivery.
      '';
      type = lib.types.attrsOf (
        let
          outerConfig = config;
        in
        lib.types.submodule (
          { name, config, ... }:
          {
            options = {
              host = lib.mkOption {
                type = lib.types.str;
                default = "${name}.${outerConfig.publicDomain}";
                description = "External hostname of the application.";
              };
              launchUrl = lib.mkOption {
                type = lib.types.str;
                default = "https://${config.host}";
                description = "URL opened from the Authentik application tile.";
              };
              iconUrl = lib.mkOption {
                type = lib.types.str;
                default = "https://raw.githubusercontent.com/homarr-labs/dashboard-icons/main/png/${name}.png";
                description = "Icon URL for the Authentik application tile.";
              };
              slug = lib.mkOption {
                type = lib.types.str;
                default = name;
                description = "Authentik application slug (and OIDC issuer path).";
              };
              issuerUrl = lib.mkOption {
                type = lib.types.str;
                default = "${outerConfig.mkTraefikServices.authentik.fullHostname}/application/o/${config.slug}";
                description = "OIDC issuer URL derived from the Authentik route and application slug.";
              };
              providerName = lib.mkOption {
                type = lib.types.str;
                default = "provider for ${name}";
                description = "Authentik OAuth2 provider name.";
              };
              redirectUris = lib.mkOption {
                type = lib.types.nonEmptyListOf lib.types.str;
                description = "Allowed authorization callback URLs (strict matching).";
              };
              logoutUri = lib.mkOption {
                type = lib.types.nullOr lib.types.str;
                default = null;
                description = "Optional OIDC logout callback URL.";
              };
              publicClient = lib.mkOption {
                type = lib.types.bool;
                default = false;
                description = "Public PKCE client; do not provision a client secret.";
              };
              credentials = {
                clientId = lib.mkOption {
                  type = credentialType {
                    inherit lib;
                    name = "${name}/oidc_client_id";
                  };
                  default = { };
                  description = "OIDC client ID sops credential.";
                };
                clientSecret = lib.mkOption {
                  type = credentialType {
                    inherit lib;
                    name = "${name}/oidc_client_secret";
                  };
                  default = { };
                  description = "OIDC client secret sops credential (unused for public clients).";
                };
              };
              displayName = lib.mkOption {
                type = lib.types.str;
                default = name;
                description = ''
                  Human-facing app name (authentik tile). Defaults
                  to the attribute name.
                '';
              };
              accessGroup = lib.mkOption {
                type = lib.types.enum accessGroupNames;
                default = "admins";
                description = ''
                  Access tier whose members can reach this app via
                  its policy binding. Same taxonomy
                  as `forwardAuthApps.<name>.accessGroup`.
                '';
              };
              displayGroup = lib.mkOption {
                type = lib.types.enum displayGroupNames;
                default = "Infrastructure";
                description = ''
                  UI display category — same taxonomy as
                  `forwardAuthApps.<name>.displayGroup`.
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
      # Typo guard: validate every registered app's accessGroup and
      # displayGroup against the fixed taxonomy declared above. The
      # enum types on the options already reject free-form strings at
      # eval time, so these assertions are belt-and-suspenders — they
      # surface a single readable message naming the offending app
      # rather than the more cryptic type-check error.
      assertions =
        let
          allApps = fwApps // oidcApps;
          invalid = name: app: [
            {
              assertion = lib.elem app.accessGroup accessGroupNames;
              message = "mkAuthentik: ${name}.accessGroup=\"${app.accessGroup}\" is not one of ${lib.concatStringsSep "," accessGroupNames}";
            }
            {
              assertion = lib.elem app.displayGroup displayGroupNames;
              message = "mkAuthentik: ${name}.displayGroup=\"${app.displayGroup}\" is not one of ${lib.concatStringsSep "," displayGroupNames}";
            }
          ];
        in
        lib.flatten (lib.mapAttrsToList invalid allApps)
        ++ [
          {
            # Sanity check the taxonomy lists themselves — a typo here
            # would silently break every assertion.
            assertion = lib.length accessGroupNames == 4 && lib.length displayGroupNames == 4;
            message = "mkAuthentik: group taxonomy lists changed shape — revisit assertions";
          }
        ];

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

      mkTraefikServices.authentik = {
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

    # Baseline groups (access hierarchy + display categories) are always
    # contributed so they exist before any app blueprint's `!Find` lookup
    # fires. Race-resilient via worker auto-retry.
    {
      mkAuthentik.extraBlueprints = [ groupsBaselineDir ];
    }

    # Forward-auth apps own the outpost's global providers list. OIDC
    # blueprints use the baseline groups supplied independently above.
    (lib.mkIf (fwApps != { }) {
      mkAuthentik.extraBlueprints = [ fwBlueprintDir ];
    })

    (lib.mkIf (oidcApps != { }) {
      sops.secrets = lib.foldl' lib.mergeAttrs { } (
        lib.mapAttrsToList (
          _: app:
          {
            ${app.credentials.clientId.secretName} = mkOidcSecret app.credentials.clientId;
          }
          // lib.optionalAttrs (!app.publicClient) {
            ${app.credentials.clientSecret.secretName} = mkOidcSecret app.credentials.clientSecret;
          }
        ) oidcApps
      );

      sops.templates."authentik-oidc-apps.env" = {
        content = oidcWorkerEnvContent;
        restartUnits = restartAuthentik;
      };

      systemd.services.authentik.serviceConfig.EnvironmentFile = [
        config.sops.templates."authentik-oidc-apps.env".path
      ];
      systemd.services.authentik-worker.serviceConfig.EnvironmentFile = [
        config.sops.templates."authentik-oidc-apps.env".path
      ];
      systemd.services.authentik-migrate.serviceConfig.EnvironmentFile = [
        config.sops.templates."authentik-oidc-apps.env".path
      ];

      mkAuthentik.extraBlueprints = lib.mapAttrsToList (
        appName: app: oidcBlueprintDir appName app
      ) oidcApps;
    })
  ];
}
