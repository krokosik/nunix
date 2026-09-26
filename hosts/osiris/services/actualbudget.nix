# Actual Budget - personal finance + budgeting
{
  config,
  lib,
  ...
}:
let
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
    redirectUris = [ "${config.mkTraefikServices.actual.fullHostname}/openid/callback" ];
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

  systemd.services.actual.serviceConfig.ReadWritePaths = lib.mkForce [
    config.services.actual.settings.dataDir
  ];

  mkTraefikServices.actual = {
    inherit port;
    public = true;
    chain = [ "chain-no-auth" ];
  };
}
