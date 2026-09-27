{
  config,
  lib,
  pkgs,
  ...
}:
{
  mkAuthentik.oidcApps.grafana = {
    # The Authentik application host and callback must use the same private
    # hostname as Grafana's Traefik route and root_url.
    host = lib.removePrefix "https://" config.mkTraefikServices.grafana.fullHostname;
    displayName = "Grafana";
    displayGroup = "Infrastructure";
    accessGroup = "admins";
    launchUrl = config.mkTraefikServices.grafana.fullHostname;
    redirectUris = [ "${config.mkTraefikServices.grafana.fullHostname}/login/generic_oauth" ];
  };

  mkTraefikServices.grafana = {
    port = config.services.grafana.settings.server.http_port;
    chain = [ "chain-no-auth" ];
  };

  sops.secrets.grafana_secret_key = {
    key = "grafana/secret_key";
    owner = "grafana";
    restartUnits = [ "grafana.service" ];
  };
  sops.secrets.grafana_admin_password = {
    key = "grafana/admin_password";
    owner = "grafana";
    restartUnits = [ "grafana.service" ];
  };

  sops.templates."grafana-oauth.env" = {
    content = ''
      GF_AUTH_GENERIC_OAUTH_CLIENT_ID=${
        config.sops.placeholder.${config.mkAuthentik.oidcApps.grafana.credentials.clientId.secretName}
      }
      GF_AUTH_GENERIC_OAUTH_CLIENT_SECRET=${
        config.sops.placeholder.${config.mkAuthentik.oidcApps.grafana.credentials.clientSecret.secretName}
      }
    '';
    owner = "grafana";
    restartUnits = [ "grafana.service" ];
  };

  systemd.services.grafana.serviceConfig.EnvironmentFile = [
    config.sops.templates."grafana-oauth.env".path
  ];

  services.grafana = {
    enable = true;
    declarativePlugins = [ pkgs.grafanaPlugins.victoriametrics-logs-datasource ];
    settings = {
      server = {
        http_addr = "127.0.0.1";
        http_port = 3001;
        root_url = config.mkTraefikServices.grafana.fullHostname;
      };
      security.secret_key = "$__file{${config.sops.secrets.grafana_secret_key.path}}";
      security.admin_password = "$__file{${config.sops.secrets.grafana_admin_password.path}}";
      security.cookie_secure = true;
      analytics.reporting_enabled = false;
      users.auto_assign_org_role = "Viewer";
      "auth.generic_oauth" = {
        enabled = true;
        name = "Authentik";
        allow_sign_up = true;
        scopes = "openid email profile";
        auth_url = "${config.mkTraefikServices.authentik.fullHostname}/application/o/authorize/";
        token_url = "${config.mkTraefikServices.authentik.fullHostname}/application/o/token/";
        api_url = "${config.mkTraefikServices.authentik.fullHostname}/application/o/userinfo/";
        role_attribute_path = "contains(groups[*], 'admins') && 'Admin' || 'Viewer'";
      };
    };
    provision = {
      enable = true;
      datasources.settings = {
        prune = true;
        datasources = [
          {
            name = "VictoriaMetrics";
            uid = "victoriametrics";
            type = "prometheus";
            url = "http://${config.services.victoriametrics.listenAddress}";
            isDefault = true;
            jsonData.timeInterval = "30s";
          }
          {
            name = "VictoriaLogs";
            uid = "victorialogs";
            type = "victoriametrics-logs-datasource";
            url = "http://${config.services.victorialogs.listenAddress}";
          }
          {
            name = "Alertmanager";
            uid = "alertmanager";
            type = "alertmanager";
            url = "http://127.0.0.1:${toString config.services.prometheus.alertmanager.port}";
            jsonData.implementation = "prometheus";
          }
        ];
      };
    };
  };
}
