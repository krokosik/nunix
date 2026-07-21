# Authentik — native systemd units via authentik-nix.
# Scope: server + worker + migrate only. Blueprints / forward-auth / OIDC / LDAP
# aggregator options are deferred until the native instance is up, then
# re-introduced incrementally alongside per-app blueprint migration.
{
  inputs,
  config,
  pkgs,
  ...
}:
let
  port = 9000;
  restartAuthentik = [
    "authentik.service"
    "authentik-worker.service"
    "authentik-migrate.service"
  ];
in
{
  imports = [ inputs.authentik-nix.nixosModules.default ];

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
    };
  };

  myTraefikServices.authentik = {
    inherit port;
    public = true;
    chain = [ "chain-no-auth" ];
  };

  # Heal DynamicUser+StateDirectory idmap and rsynced appdata ownership.
  systemd.services.authentik-migrate.serviceConfig.ExecStartPre = [
    "+${pkgs.writeShellScript "authentik-state-chown" ''
      ${pkgs.coreutils}/bin/chown -R authentik:authentik /var/lib/private/authentik
    ''}"
  ];
}
