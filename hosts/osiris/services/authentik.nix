# Authentik — native systemd units via authentik-nix.
# Owns the `mkAuthentik` option namespace that app modules contribute to:
#   * extraBlueprints   — blueprint dirs merged into authentik's blueprints_dir
#   * forwardAuthApps   — apps gated by the embedded outpost via Traefik
#                         forward_auth (chain-authentik middleware)
#   * oidcApps          — apps that speak OIDC against authentik directly
#   * launcherApps      — dashboard links without authentication providers
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
  inherit (lib.attrsets)
    attrNames
    filterAttrs
    mapAttrsToList
    optionalAttrs
    ;
  inherit (lib.lists)
    concatMap
    elem
    flatten
    foldl'
    length
    optionals
    singleton
    ;
  inherit (lib.meta) getExe getExe';
  inherit (lib.modules) mkIf mkMerge;
  inherit (lib.options) mkOption;
  inherit (lib.trivial) mergeAttrs;
  inherit (lib.strings)
    concatMapStringsSep
    concatStrings
    concatStringsSep
    escapeShellArg
    optionalString
    replaceStrings
    toJSON
    toUpper
    ;
  inherit (lib.types)
    attrsOf
    bool
    enum
    listOf
    nonEmptyListOf
    nullOr
    path
    str
    submodule
    ;
  chownExe = getExe' pkgs.coreutils "chown";
  curlExe = getExe pkgs.curl;
  manageExe = getExe' config.services.authentik.authentikComponents.manage "manage.py";
  restartAuthentik = [
    "authentik.service"
    "authentik-worker.service"
    "authentik-migrate.service"
  ];

  fwApps = config.mkAuthentik.forwardAuthApps;
  fwAppNames = attrNames fwApps;
  basicAuthApps = filterAttrs (_: { basicAuth, ... }: basicAuth != null) fwApps;

  inherit (config.mkAuthentik) oidcApps launcherApps;
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
  groupsBaselineContent = /* yaml */ ''
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
            - !KeyOf grp-family
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
  perFwAppEntries = name: app: /* yaml */ ''
    - model: authentik_providers_proxy.proxyprovider
      id: prov-${name}
      identifiers:
        name: ${name}
      attrs:
        mode: ${app.mode}
        external_host: ${app.host}
    ${optionalString (app.mode == "forward_domain") "    cookie_domain: ${app.cookieDomain}"}
        authentication_flow: !Find [authentik_flows.flow, [slug, default-authentication-flow]]
        authorization_flow: !Find [authentik_flows.flow, [slug, default-provider-authorization-implicit-consent]]
        invalidation_flow: !Find [authentik_flows.flow, [slug, default-provider-invalidation-flow]]
    ${optionalString (app.basicAuth != null) (
      concatStringsSep "\n" [
        "    basic_auth_enabled: true"
        "    basic_auth_user_attribute: ${name}_user"
        "    basic_auth_password_attribute: ${name}_password"
      ]
    )}

    - model: authentik_core.application
      id: app-${name}
      identifiers:
        slug: ${name}
      attrs:
        name: ${app.displayName}
        provider: !KeyOf prov-${name}
        group: ${app.displayGroup}
        open_in_new_tab: true
        meta_launch_url: ${app.launchUrl}
        meta_icon: ${app.iconUrl}
    ${optionalString app.hide "    meta_hide: true"}
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
  outpostProviders = concatMapStringsSep "\n      " (
    n: "- !Find [authentik_providers_proxy.proxyprovider, [name, ${n}]]"
  ) fwAppNames;

  # `authentik_host` is the base URL the outpost uses to reach the
  # authentik server; `authentik_host_browser` is the base URL the
  # outpost emits in 302 Location headers. With both unset, the
  # outpost falls back to its bind address (http://0.0.0.0:9000),
  # which a browser can't resolve. Encoding both here makes
  # forward-auth deterministic across hosts.
  outpostEntry = /* yaml */ ''
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

  fwBlueprintContent = /* yaml */ ''
    version: 1
    metadata:
      name: forward-auth-apps
    entries:
    ${concatStringsSep "\n\n" ((mapAttrsToList perFwAppEntries fwApps) ++ singleton outpostEntry)}
  '';

  fwBlueprintDir = pkgs.writeTextDir "forward-auth-apps.yaml" fwBlueprintContent;

  # Group attributes cannot be filled in at build time. The oneshot reads
  # sops credentials and updates only the admins group's Basic credentials.
  adminBasicAuthAttributes = concatMapStringsSep ",\n" (
    name:
    ''"${name}_user": os.environ["${toUpper name}_USERNAME"], "${name}_password": os.environ["${toUpper name}_PASSWORD"]''
  ) (attrNames basicAuthApps);

  adminBasicAuthCommand = pkgs.writeText "authentik-admin-basic-auth.py" /* python */ ''
    import os
    from authentik.core.models import Group

    group = Group.objects.get(name="admins")
    attrs = {${adminBasicAuthAttributes}}
    group.update_attributes({"attributes": attrs})
  '';

  adminBasicAuthScript = pkgs.writeShellScript "authentik-admin-basic-auth" /* bash */ ''
    set -euo pipefail
    ${concatMapStringsSep "\n" (name: /* bash */ ''
      test -s "$CREDENTIALS_DIRECTORY/${name}_password"
      export ${toUpper name}_USERNAME=${escapeShellArg basicAuthApps.${name}.basicAuth.username}
      export ${toUpper name}_PASSWORD="$(<"$CREDENTIALS_DIRECTORY/${name}_password")"
    '') (attrNames basicAuthApps)}
    exec ${manageExe} shell \
      < ${adminBasicAuthCommand}
  '';

  # Quote user-provided YAML scalars, keeping URLs and names safe from
  # YAML punctuation and preventing a value from becoming a YAML tag.
  yamlString = value: toJSON value;

  launcherBlueprintDir =
    name: app:
    pkgs.writeTextDir "launcher-${name}.yaml" /* yaml */ ''
      version: 1
      metadata:
        name: launcher-${name}
      entries:
        - model: authentik_core.application
          id: app-${name}
          identifiers:
            slug: ${yamlString app.slug}
          attrs:
            name: ${yamlString app.displayName}
            provider: null
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
            group: !Find [authentik_core.group, [name, ${yamlString app.accessGroup}]]
            enabled: true
    '';

  oidcEnvName =
    name: kind:
    "AUTHENTIK_OIDC_${toUpper (replaceStrings (singleton "-") (singleton "_") name)}_${kind}";

  oidcBlueprintDir =
    name: app:
    let
      providerFields = concatStringsSep "\n" (
        singleton "      client_id: !Env ${oidcEnvName name "CLIENT_ID"}"
        ++ optionals (!app.publicClient) (
          singleton "      client_secret: !Env ${oidcEnvName name "CLIENT_SECRET"}"
        )

        ++ [
          "      client_type: ${if app.publicClient then "public" else "confidential"}"
          "      grant_types: [authorization_code, refresh_token]"
          "      authorization_flow: !Find [authentik_flows.flow, [slug, default-provider-authorization-implicit-consent]]"
          "      invalidation_flow: !Find [authentik_flows.flow, [slug, default-provider-invalidation-flow]]"
          "      signing_key: !Find [authentik_crypto.certificatekeypair, [name, authentik Self-signed Certificate]]"
          "      issuer_mode: per_provider"
          "      property_mappings:"
          "        - !Find [authentik_providers_oauth2.scopemapping, [managed, goauthentik.io/providers/oauth2/scope-openid]]"
          "        - !Find [authentik_providers_oauth2.scopemapping, [managed, goauthentik.io/providers/oauth2/scope-email]]"
          "        - !Find [authentik_providers_oauth2.scopemapping, [managed, goauthentik.io/providers/oauth2/scope-profile]]"
        ]
        ++ optionals (app.logoutMethod != null) (singleton "      logout_method: ${app.logoutMethod}")
        ++ optionals (app.logoutUri != null) (singleton "      logout_uri: ${yamlString app.logoutUri}")
        ++ singleton "      redirect_uris:"
        ++ concatMap (url: [
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
    idLine + "\n" + optionalString (!app.publicClient) (secretLine + "\n");

  oidcWorkerEnvContent = concatStrings (mapAttrsToList oidcWorkerEnvLines oidcApps);

  # Stack upstream blueprints + every contributed dir into a single
  # real-file directory. Copy with `-L` to dereference: authentik's
  # `retrieve_file` calls `Path(...).resolve()` on every blueprint and
  # rejects anything that resolves outside `blueprints_dir`, so
  # `symlinkJoin` (top-level entries are symlinks back to source store
  # paths) makes every apply fail with "Invalid blueprint path".
  mergedBlueprints = pkgs.callPackage (
    { runCommandLocal }:
    runCommandLocal "authentik-blueprints-merged" { } /* bash */ ''
      mkdir --parents "$out"
      cp --recursive --dereference ${config.services.authentik.authentikComponents.staticWorkdirDeps}/blueprints/. "$out/"
      chmod --recursive u+w "$out"
      ${concatMapStringsSep "\n" (p: /* bash */ ''
        cp --recursive --dereference ${p}/. "$out/"
        chmod --recursive u+w "$out"
      '') config.mkAuthentik.extraBlueprints}
    ''
  ) { };
in
{
  imports = singleton inputs.authentik-nix.nixosModules.default;

  options.mkAuthentik = {
    extraBlueprints = mkOption {
      type = listOf path;
      default = [ ];
      description = ''
        Extra blueprint directories or files to merge into authentik's
        blueprints_dir alongside the bundled defaults. Each entry is a
        path containing one or more *.yaml blueprint files. Other app
        modules can append their own blueprints here so each app stays
        self-contained.
      '';
    };

    forwardAuthApps = mkOption {
      default = { };
      description = ''
        Apps gated by authentik forward-auth via Traefik (chain-authentik
        middleware). Each entry generates an authentik proxy provider +
        application + policy binding, plus the embedded outpost's
        `providers` list entry. One blueprint owns the outpost's
        `providers` list, so every forward-auth app on the host must
        register through this option rather than emitting its own
        outpost block. Regular apps use `forward_single` and configure their
        Traefik router + middleware chain in the service module via
        `mkTraefikServices.<name>`. A domain-level provider uses
        `mode = "forward_domain"` with an explicit `host` and `cookieDomain`;
        it does not require an app route.

        Both `accessGroup` and `displayGroup` are validated against the
        fixed taxonomy declared in this module (see `accessGroupNames`
        / `displayGroupNames`) — typos fail the build via assertions.
      '';
      type = attrsOf (
        submodule (
          { name, ... }:
          {
            options = {
              host = mkOption {
                type = str;
                default = config.mkTraefikServices.${name}.fullHostname;
                description = "External URL Traefik matches (or the domain-level authentication URL).";
              };
              launchUrl = mkOption {
                type = str;
                default = config.mkAuthentik.forwardAuthApps.${name}.host;
                description = "URL opened from the application tile; may include a UI path without changing the authentication hostname.";
              };
              mode = mkOption {
                type = enum [
                  "forward_single"
                  "forward_domain"
                ];
                default = "forward_single";
                description = "Authentik proxy provider forward-auth mode.";
              };
              cookieDomain = mkOption {
                type = nullOr str;
                default = null;
                description = "Cookie domain shared by hosts using a domain-level provider.";
              };
              displayName = mkOption {
                type = str;
                description = "Human-facing app name (authentik tile).";
              };
              hide = mkOption {
                type = bool;
                default = false;
                description = "Hide this application from the Authentik library (e.g. a domain-level provider).";
              };
              iconUrl = mkOption {
                type = str;
                default = "https://raw.githubusercontent.com/homarr-labs/dashboard-icons/main/png/${name}.png";
                description = "Icon URL used on the authentik application tile.";
              };
              accessGroup = mkOption {
                type = enum accessGroupNames;
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
              displayGroup = mkOption {
                type = enum displayGroupNames;
                default = "Infrastructure";
                description = ''
                  UI display category for the application library tile.
                  One of: Infrastructure, Arr, Apps, Finance. Defaults to
                  Infrastructure (admin/ops tools). Purely cosmetic —
                  no policy evaluation touches display groups.
                '';
              };
              basicAuth = mkOption {
                type = nullOr (submodule {
                  options = {
                    username = mkOption {
                      type = str;
                      description = "Upstream Basic Auth username.";
                    };
                    passwordSecretName = mkOption {
                      type = str;
                      description = "Name of an existing sops secret holding the upstream Basic Auth password.";
                    };
                  };
                });
                default = null;
                description = "Enable upstream HTTP Basic Auth, using credentials restricted to Authentik admins.";
              };
            };
          }
        )
      );
    };

    launcherApps = mkOption {
      default = { };
      description = ''
        Dashboard links without an authentication provider. Each entry generates
        an application and group policy binding. The binding controls tile
        visibility only; the destination service owns its authentication.
      '';
      type = attrsOf (
        let
          outerConfig = config;
        in
        submodule (
          { name, config, ... }:
          {
            options = {
              host = mkOption {
                type = str;
                default = "${name}.${outerConfig.publicDomain}";
                description = "External hostname of the application.";
              };
              launchUrl = mkOption {
                type = str;
                default = "https://${config.host}";
                description = "URL opened from the Authentik application tile.";
              };
              iconUrl = mkOption {
                type = str;
                default = "https://raw.githubusercontent.com/homarr-labs/dashboard-icons/main/png/${name}.png";
                description = "Icon URL for the Authentik application tile.";
              };
              slug = mkOption {
                type = str;
                default = name;
                description = "Authentik application slug.";
              };
              displayName = mkOption {
                type = str;
                default = name;
                description = "Human-facing name of the application tile.";
              };
              accessGroup = mkOption {
                type = enum accessGroupNames;
                default = "admins";
                description = "Access tier allowed to see the launcher tile.";
              };
              displayGroup = mkOption {
                type = enum displayGroupNames;
                default = "Infrastructure";
                description = "Display category of the application tile.";
              };
            };
          }
        )
      );
    };

    oidcApps = mkOption {
      default = { };
      description = ''
        Apps that authenticate against Authentik via OIDC directly
        (the app speaks OIDC; we do not use the embedded outpost).
        Each entry provisions sops credentials, generates the OAuth2
        provider, application and access-policy binding blueprint, and
        makes the credentials available to Authentik via `!Env`. The
        consuming service owns its own credential delivery.
      '';
      type = attrsOf (
        let
          outerConfig = config;
        in
        submodule (
          { name, config, ... }:
          {
            options = {
              host = mkOption {
                type = str;
                default = "${name}.${outerConfig.publicDomain}";
                description = "External hostname of the application.";
              };
              launchUrl = mkOption {
                type = str;
                default = "https://${config.host}";
                description = "URL opened from the Authentik application tile.";
              };
              iconUrl = mkOption {
                type = str;
                default = "https://raw.githubusercontent.com/homarr-labs/dashboard-icons/main/png/${name}.png";
                description = "Icon URL for the Authentik application tile.";
              };
              slug = mkOption {
                type = str;
                default = name;
                description = "Authentik application slug (and OIDC issuer path).";
              };
              issuerUrl = mkOption {
                type = str;
                default = "${outerConfig.mkTraefikServices.authentik.fullHostname}/application/o/${config.slug}/";
                description = "OIDC issuer URL derived from the Authentik route and application slug.";
              };
              providerName = mkOption {
                type = str;
                default = "provider for ${name}";
                description = "Authentik OAuth2 provider name.";
              };
              redirectUris = mkOption {
                type = nonEmptyListOf str;
                description = "Allowed authorization callback URLs (strict matching).";
              };
              logoutUri = mkOption {
                type = nullOr str;
                default = null;
                description = "Optional OIDC logout callback URL.";
              };
              logoutMethod = mkOption {
                type = nullOr (enum [
                  "backchannel"
                  "frontchannel"
                ]);
                default = null;
                description = "Optional Authentik OAuth2 logout method; null leaves Authentik's default.";
              };
              publicClient = mkOption {
                type = bool;
                default = false;
                description = "Public PKCE client; do not provision a client secret.";
              };
              credentials = {
                clientId = mkOption {
                  type = credentialType {
                    inherit lib;
                    name = "${name}/oidc_client_id";
                  };
                  default = { };
                  description = "OIDC client ID sops credential.";
                };
                clientSecret = mkOption {
                  type = credentialType {
                    inherit lib;
                    name = "${name}/oidc_client_secret";
                  };
                  default = { };
                  description = "OIDC client secret sops credential (unused for public clients).";
                };
              };
              displayName = mkOption {
                type = str;
                default = name;
                description = ''
                  Human-facing app name (authentik tile). Defaults
                  to the attribute name.
                '';
              };
              accessGroup = mkOption {
                type = enum accessGroupNames;
                default = "admins";
                description = ''
                  Access tier whose members can reach this app via
                  its policy binding. Same taxonomy
                  as `forwardAuthApps.<name>.accessGroup`.
                '';
              };
              displayGroup = mkOption {
                type = enum displayGroupNames;
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

  config = mkMerge [
    {
      # Typo guard: validate every registered app's accessGroup and
      # displayGroup against the fixed taxonomy declared above. The
      # enum types on the options already reject free-form strings at
      # eval time, so these assertions are belt-and-suspenders — they
      # surface a single readable message naming the offending app
      # rather than the more cryptic type-check error.
      assertions =
        let
          allApps = fwApps // oidcApps // launcherApps;
          invalid = name: app: [
            {
              assertion = elem app.accessGroup accessGroupNames;
              message = "mkAuthentik: ${name}.accessGroup=\"${app.accessGroup}\" is not one of ${concatStringsSep "," accessGroupNames}";
            }
            {
              assertion = elem app.displayGroup displayGroupNames;
              message = "mkAuthentik: ${name}.displayGroup=\"${app.displayGroup}\" is not one of ${concatStringsSep "," displayGroupNames}";
            }
          ];
        in
        flatten (mapAttrsToList invalid allApps)
        ++ singleton {
          # Sanity check the taxonomy lists themselves — a typo here
          # would silently break every assertion.
          assertion = length accessGroupNames == 4 && length displayGroupNames == 4;
          message = "mkAuthentik: group taxonomy lists changed shape — revisit assertions";
        }

        # A domain-level provider must be explicit about cookie scope; a
        # single-app provider cannot accidentally set a broad cookie domain.
        ++ mapAttrsToList (name: app: {
          assertion = (app.mode == "forward_domain") == (app.cookieDomain != null);
          message = "mkAuthentik.forwardAuthApps.${name}: cookieDomain is required only for forward_domain";
        }) fwApps;

      sops = {
        secrets = {
          authentik_secret_key.key = "authentik/secret_key";
          authentik_bootstrap_email.key = "authentik/bootstrap_email";
          authentik_bootstrap_password.key = "authentik/bootstrap_password";
          authentik_bootstrap_token.key = "authentik/bootstrap_token";
        };

        templates."authentik.env" = {
          content = /* bash */ ''
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
        port = 9000;
        public = true;
        chain = singleton "chain-no-auth";
      };

      mkObservabilityServices = {
        authentik = {
          metrics.url = "http://127.0.0.1:9300/metrics";
          units = [
            config.systemd.services.authentik.name
            config.systemd.services.authentik-worker.name
          ];
          probes.public.url = "${config.mkTraefikServices.authentik.fullHostname}/-/health/ready/";
          logAlerts = singleton {
            alert = "AuthentikUserSignup";
            interval = "30s";
            # Overlap evaluations to tolerate ingestion delays. Group by username
            # so each signup has its own Alertmanager notification identity.
            expr = /* logsql */ ''
              _time:5m _SYSTEMD_UNIT:in("authentik.service", "authentik-worker.service")
              | unpack_json
              | filter event:="Created Event" action:="user_write" context.created:="true"
              | rename context.username as username
              | stats by (_HOSTNAME, username) count() as signups
              | filter signups:>0
            '';
            labels = {
              severity = "info";
              service = "authentik";
            };
            annotations = {
              summary = "New Authentik signup: {{ $labels.username }}";
              dashboard_url = "${config.mkTraefikServices.authentik.fullHostname}/if/admin/#/identity/users";
              dashboard_label = "Users";
            };
          };
        };

        authentik-worker.metrics.url = "http://[::1]:9301/metrics";
      };

      mkObservability = {
        repeatedErrorUnits = mkIf config.services.authentik.enable config.mkObservabilityServices.authentik.units;

        inactiveAlertUnits = mkIf config.services.authentik.enable config.mkObservabilityServices.authentik.units;
      };

      systemd.services = {
        # Heal DynamicUser+StateDirectory idmap and rsynced appdata ownership.
        authentik-migrate.serviceConfig.ExecStartPre = singleton "+${
          pkgs.writeShellScript "authentik-state-chown" /* bash */ ''
            ${chownExe} --recursive authentik:authentik /var/lib/private/authentik
          ''
        }";

        # Real readiness boundary for the authentik stack. The three
        # native units are all Type=simple, so systemd considers them
        # "active" long before Django answers HTTP. /-/health/ready/
        # returns 200 only after Django can answer, so probing it gives
        # dependents a real readiness gate. RemainAfterExit+PartOf
        # propagates authentik's stop/restart here so the gate is torn
        # down with authentik and re-runs its poll before dependents
        # that restart in the same transaction proceed.
        authentik-ready = {
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
          script = /* bash */ ''
            until ${curlExe} --fail --silent --show-error --output /dev/null \
              --max-time 3 http://localhost:${toString config.mkTraefikServices.authentik.port}/-/health/ready/; do
              sleep 2
            done
          '';
        };
      };
    }

    # Baseline groups (access hierarchy + display categories) are always
    # contributed so they exist before any app blueprint's `!Find` lookup
    # fires. Race-resilient via worker auto-retry.
    {
      mkAuthentik.extraBlueprints = singleton groupsBaselineDir;
    }

    {
      mkAuthentik.extraBlueprints = mapAttrsToList launcherBlueprintDir launcherApps;
    }

    # Forward-auth apps own the outpost's global providers list. OIDC
    # blueprints use the baseline groups supplied independently above.
    (mkIf (fwApps != { }) {
      mkAuthentik.extraBlueprints = singleton fwBlueprintDir;
    })

    # KWS provides domain-level forward auth for hosts without their own
    # single-app proxy provider; it is not a Traefik router or web service.
    {
      mkAuthentik.forwardAuthApps.kws = {
        displayName = "KWS";
        mode = "forward_domain";
        host = config.mkTraefikServices.authentik.fullHostname;
        cookieDomain = config.publicDomain;
        hide = true;
        accessGroup = "admins";
      };
    }

    (mkIf (basicAuthApps != { }) {
      assertions = mapAttrsToList (name: app: {
        assertion = app.accessGroup == "admins";
        message = "mkAuthentik.forwardAuthApps.${name}: basicAuth requires accessGroup = admins";
      }) basicAuthApps;

      systemd.services.authentik-admin-basic-auth = {
        description = "Update Authentik admins' Basic Auth credentials";
        after = singleton "authentik-ready.service";
        requires = singleton "authentik-ready.service";
        wantedBy = singleton "multi-user.target";
        environment.PYTHONPATH = "${config.services.authentik.authentikComponents.staticWorkdirDeps}";
        path = singleton config.services.authentik.authentikComponents.pythonEnv;
        serviceConfig = {
          Type = "oneshot";
          DynamicUser = true;
          User = "authentik";
          StateDirectory = "authentik";
          WorkingDirectory = "/var/lib/authentik";
          EnvironmentFile = singleton config.sops.templates."authentik.env".path;
          LoadCredential = mapAttrsToList (
            name: app: "${name}_password:${config.sops.secrets.${app.basicAuth.passwordSecretName}.path}"
          ) basicAuthApps;
          ExecStart = adminBasicAuthScript;
        };
      };
    })

    (mkIf (oidcApps != { }) {
      sops = {
        secrets = foldl' mergeAttrs { } (
          mapAttrsToList (
            _: app:
            {
              ${app.credentials.clientId.secretName} = mkOidcSecret app.credentials.clientId;
            }
            // optionalAttrs (!app.publicClient) {
              ${app.credentials.clientSecret.secretName} = mkOidcSecret app.credentials.clientSecret;
            }
          ) oidcApps
        );

        templates."authentik-oidc-apps.env" = {
          content = oidcWorkerEnvContent;
          restartUnits = restartAuthentik;
        };
      };

      systemd.services = {
        authentik.serviceConfig.EnvironmentFile =
          singleton
            config.sops.templates."authentik-oidc-apps.env".path;
        authentik-worker.serviceConfig.EnvironmentFile =
          singleton
            config.sops.templates."authentik-oidc-apps.env".path;
        authentik-migrate.serviceConfig.EnvironmentFile =
          singleton
            config.sops.templates."authentik-oidc-apps.env".path;
      };

      mkAuthentik.extraBlueprints = mapAttrsToList (appName: app: oidcBlueprintDir appName app) oidcApps;
    })
  ];
}
