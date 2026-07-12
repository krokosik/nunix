{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:
let
  secretspath = toString inputs.my-secrets;
in
{
  environment.etc."crowdsec/config.yaml".source =
    (pkgs.formats.yaml { }).generate "crowdsec.yaml"
      config.services.crowdsec.settings.general;

  services.crowdsec = {
    enable = true;
    autoUpdateService = true;
    name = config.networking.hostName;

    hub.collections = [
      "crowdsecurity/sshd"
      "crowdsecurity/linux"
      "crowdsecurity/http-cve"
      "crowdsecurity/base-http-scenarios"
      "crowdsecurity/whitelist-good-actors"
      "crowdsecurity/traefik"
      "crowdsecurity/http-cve"
      "crowdsecurity/whitelist-good-actors"
      "crowdsecurity/iptables"
      "crowdsecurity/appsec-virtual-patching"
      "crowdsecurity/appsec-generic-rules"
    ];

    hub.appSecConfigs = [
      "crowdsecurity/appsec-default"
    ];

    localConfig.acquisitions = [
      {
        source = "journalctl";
        journalctl_filter = [ "_SYSTEMD_UNIT=sshd.service" ];
        labels.type = "syslog";
      }
      {
        source = "journalctl";
        journalctl_filter = [ "_SYSTEMD_UNIT=traefik.service" ];
        labels.type = "traefik";
      }
      {
        source = "appsec";
        listen_addr = "127.0.0.1:7422";
        appsec_config = "crowdsecurity/appsec-default";
        labels.type = "appsec";
      }
    ];

    settings = {
      # broken conditional in upstream
      # console.tokenFile = config.sops.secrets.crowdsec_console_token.path;
      capi.credentialsFile = "/var/lib/crowdsec/state/online_api_credentials.yaml";
      lapi.credentialsFile = "/var/lib/crowdsec/state/local_api_credentials.yaml";
      general.api.server = {
        enable = true;
        listen_uri = "127.0.0.1:8420";
        console_path = "/var/lib/crowdsec/state/console.yaml";
      };
    };
  };

  services.crowdsec-firewall-bouncer = {
    enable = true;
    registerBouncer.enable = true;
    settings = {
      insecure_skip_verify = false;
      deny_action = "DROP";
      supported_decisions_types = [ "ban" ];
    };
  };

  services.traefik = {
    dynamicConfigOptions.http = {
      services.crowdsec-svc.loadBalancer.servers = [
        { url = "http://${config.services.crowdsec.settings.general.api.server.listen_uri}"; }
      ];
      routers.crowdsec-rtr = {
        rule = "Host(`crowdsec.${config.privateDomain}`)";
        entryPoints = [ "websecure" ];
        service = "crowdsec-svc";
        middlewares = [ "chain-lapi" ];
      };
    };
  };

  systemd.services.crowdsec =
    let
      vpsHostname = "anubis";
    in
    {
      serviceConfig = {
        DynamicUser = lib.mkForce false;
        StateDirectory = "crowdsec";
      };
      postStart = ''
        export USER=${config.users.users.crowdsec.name}
        CSCLI="/run/current-system/sw/bin/cscli"

        if ! $CSCLI console status -o raw | ${pkgs.gnugrep}/bin/grep -q "true"; then
          $CSCLI console enroll "$(< ${config.sops.secrets.crowdsec_console_token.path})" --name ${config.services.crowdsec.name}
        fi

        # Inject VPS Agent (anubis)
        if ! $CSCLI machines list -o json | ${pkgs.jq}/bin/jq -e '.[] | select(.machineId == "${vpsHostname}")' > /dev/null; then
           $CSCLI machines add ${vpsHostname} --password "$(< ${config.sops.secrets.crowdsec_vps_machine_password.path})" -f - > /dev/null
        fi

        # Inject VPS Bouncer
        if ! $CSCLI bouncers list -o json | ${pkgs.jq}/bin/jq -e '.[] | select(.name == "${vpsHostname}-bouncer")' > /dev/null; then
           $CSCLI bouncers add ${vpsHostname}-bouncer --key "$(< ${config.sops.secrets.crowdsec_vps_bouncer_key.path})"
        fi

        # Inject Traefik Bouncer
        if ! $CSCLI bouncers list -o json | ${pkgs.jq}/bin/jq -e '.[] | select(.name == "traefik-bouncer")' > /dev/null; then
           $CSCLI bouncers add traefik-bouncer --key "$(< ${config.sops.secrets.crowdsec_traefik_bouncer_key.path})"
        fi
      '';
    };

  systemd.services.crowdsec-update-hub.serviceConfig.DynamicUser = lib.mkForce false;
  systemd.services.crowdsec-firewall-bouncer.serviceConfig.DynamicUser = lib.mkForce false;
  systemd.services.crowdsec-firewall-bouncer-register.serviceConfig.DynamicUser = lib.mkForce false;

  sops.secrets = {
    crowdsec_console_token = {
      key = "crowdsec/console_token";
      mode = "0400";
      owner = config.users.users.crowdsec.name;
      restartUnits = [ "crowdsec.service" ];
    };
    crowdsec_vps_machine_password = {
      sopsFile = "${secretspath}/server/secrets.yaml";
      key = "crowdsec/vps_machine_password";
      mode = "0400";
      owner = config.users.users.crowdsec.name;
      restartUnits = [ "crowdsec.service" ];
    };
    crowdsec_vps_bouncer_key = {
      sopsFile = "${secretspath}/server/secrets.yaml";
      key = "crowdsec/vps_bouncer_key";
      mode = "0400";
      owner = config.users.users.crowdsec.name;
      restartUnits = [ "crowdsec.service" ];
    };
  };
}
