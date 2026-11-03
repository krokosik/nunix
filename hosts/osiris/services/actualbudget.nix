# Actual Budget - personal finance + budgeting
{
  config,
  lib,
  ...
}:
let
  inherit (lib.lists) singleton;
  inherit (lib.modules) mkForce mkIf;
  port = 5006;
  user = "actual";
  group = "actual";
  oidc = config.mkAuthentik.oidcApps.actual;
in
{
  mkAuthentik.oidcApps.actual = {
    displayName = "Actual Budget";
    displayGroup = "Finance";
    accessGroup = "friends";
    iconUrl = "https://raw.githubusercontent.com/homarr-labs/dashboard-icons/main/png/actual-budget.png";
    redirectUris = singleton "${config.mkTraefikServices.actual.fullHostname}/openid/callback";
    credentials = {
      clientId = {
        inherit group;
        owner = user;
      };
      clientSecret = {
        inherit group;
        owner = user;
      };
    };
  };

  users = {
    users.actual = {
      isSystemUser = true;
      group = "actual";
    };
    groups.actual = { };
  };

  services.actual = {
    inherit user group;
    enable = true;
    settings = {
      inherit port;
      loginMethod = "openid";
      openId = {
        discoveryURL = oidc.issuerUrl;
        client_id._secret = config.sops.secrets.${oidc.credentials.clientId.secretName}.path;
        client_secret._secret = config.sops.secrets.${oidc.credentials.clientSecret.secretName}.path;
        server_hostname = config.mkTraefikServices.actual.fullHostname;
        authMethod = "openid";
      };
    };
  };

  systemd.services.actual.serviceConfig.ReadWritePaths = mkForce (
    singleton config.services.actual.settings.dataDir
  );

  mkObservability.inactiveAlertUnits = mkIf config.services.actual.enable (
    singleton config.systemd.services.actual.name
  );

  mkTraefikServices.actual = {
    inherit port;
    public = true;
    chain = singleton "chain-no-auth";
  };
}
