{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib.lists) singleton;
  configuration = {
    global.telegram_bot_token_file = config.sops.secrets.alertmanager_telegram_token.path;
    route = {
      receiver = "telegram";
      group_by = [
        "alertname"
        "host"
        "service"
      ];
      group_wait = "30s";
      group_interval = "5m";
      repeat_interval = "4h";
      routes = singleton {
        receiver = "email";
        matchers = singleton ''channel="email"'';
      };
    };
    receivers = [
      {
        name = "telegram";
        telegram_configs = singleton {
          chat_id = 1;
          send_resolved = true;
        };
      }
      {
        name = "email";
        email_configs = singleton {
          to = config.systemEmail;
          from = "${config.networking.hostName}@${config.publicDomain}";
          smarthost = "127.0.0.1:2500";
          require_tls = false;
          send_resolved = true;
        };
      }
    ];
    inhibit_rules = singleton {
      source_matchers = singleton ''alertname="HostDown"'';
      target_matchers = singleton ''alertname=~"SystemdUnitFailed|SystemdUnitInactive|HttpProbeFailed|ScrapeDown"'';
      equal = singleton "host";
    };
  };
in
{
  sops.secrets = {
    alertmanager_telegram_token = {
      key = "alertmanager/telegram_bot_token";
      owner = "alertmanager";
      restartUnits = [ "alertmanager.service" ];
    };
    alertmanager_telegram_chat_id = {
      key = "alertmanager/telegram_chat_id";
      restartUnits = [ "alertmanager.service" ];
    };
  };

  # The chat ID is numeric in Alertmanager's schema. Substitute only the
  # placeholder at startup, keeping the actual value outside the Nix store.
  systemd.services.alertmanager = {
    preStart = lib.mkAfter ''
      set -euo pipefail
      chat_id="$(<"$CREDENTIALS_DIRECTORY/telegram_chat_id")"
      [[ "$chat_id" =~ ^-?[0-9]+$ ]] || { echo "Invalid Telegram chat ID" >&2; exit 1; }
      ${lib.getExe' pkgs.gnused "sed"} "s/\"chat_id\":1/\"chat_id\":$chat_id/" /tmp/alert-manager-substituted.yaml > /tmp/alert-manager-ready.yaml
      ${lib.getExe' pkgs.coreutils "mv"} /tmp/alert-manager-ready.yaml /tmp/alert-manager-substituted.yaml
    '';
    serviceConfig.LoadCredential = [
      "telegram_chat_id:${config.sops.secrets.alertmanager_telegram_chat_id.path}"
    ];
    wants = [ "msmtpd.service" ];
    after = [ "msmtpd.service" ];
  };

  users.groups.alertmanager = { };
  users.users.alertmanager = {
    isSystemUser = true;
    group = "alertmanager";
  };

  systemd.services.alertmanager.serviceConfig = {
    DynamicUser = lib.mkForce false;
    User = "alertmanager";
    Group = "alertmanager";
  };

  services.prometheus.alertmanager = {
    enable = true;
    listenAddress = "127.0.0.1";
    checkConfig = true;
    webExternalUrl = config.mkTraefikServices.alertmanager.fullHostname;
    inherit configuration;
  };

  mkTraefikServices.alertmanager = {
    host = "127.0.0.1";
    port = config.services.prometheus.alertmanager.port;
    chain = [
      "chain-tailscale"
      "chain-authentik"
    ];
  };

  mkAuthentik.forwardAuthApps.alertmanager = {
    displayName = "Alertmanager";
    accessGroup = "admins";
    displayGroup = "Infrastructure";
  };

  mkObservability.hostMetrics.alertmanager.url = "http://127.0.0.1:${toString config.services.prometheus.alertmanager.port}/metrics";
}
