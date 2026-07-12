{
  inputs,
  config,
  pkgs,
  ...
}:
let
  secretspath = toString inputs.my-secrets;
in
{
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
      console.tokenFile = "/run/credentials/crowdsec.service/console_token";
      general.api.server = {
        enable = true;
        listen_uri = "127.0.0.1:8420";
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

  dynamicConfigOptions.http = {
    services = {
      crowdsec-svc = {
        loadBalancer.server.url = "http://${config.services.crowdsec.settings.general.api.server.listen_uri}";
      };
    };
    routers = {
      crowdsec-rtr = {
        rule = "Host(`crowdsec.${config.privateDomain}`)";
        entryPoints = [ "websecure" ];
        service = "crowdsec-svc";
        middlewares = [ "chain-lapi" ];
      };
    };
  };

  systemd.services.crowdsec.serviceConfig.LoadCredential = [
    "console_token.yaml:${config.sops.secrets.crowdsec_console_token.path}"
  ];

  sops.templates."vps.env".content = ''
    MACHINE_PWD=${config.sops.placeholder.crowdsec_vps_machine_password}
    BOUNCER_KEY=${config.sops.placeholder.crowdsec_vps_bouncer_key}
  '';

  systemd.services.crowdsec-register-vps =
    let
      vpsHostname = "anubis";
    in
    {
      description = "Declaratively register VPS in CrowdSec";
      wantedBy = [ "multi-user.target" ];
      after = [ "crowdsec.service" ];
      serviceConfig = {
        Type = "oneshot";
        User = config.users.users.crowdsec.name;
        EnvironmentFile = config.sops.templates."vps.env".path;
      };
      script = ''
        cscli=${pkgs.crowdsec}/bin/cscli

        # Inject VPS Agent (Machine) if not already registered
        if ! $cscli machines list -o json | ${pkgs.jq}/bin/jq -e '.[] | select(.machineId == "${vpsHostname}")' > /dev/null; then
           $cscli machines add ${vpsHostname} --password "$MACHINE_PWD"
        fi

        # Inject VPS Bouncer if not already registered
        if ! $cscli bouncers list -o json | ${pkgs.jq}/bin/jq -e '.[] | select(.name == "${vpsHostname}-bouncer")' > /dev/null; then
           $cscli bouncers add ${vpsHostname}-bouncer --key "$BOUNCER_KEY"
        fi
      '';
    };

  sops.secrets = {
    crowdsec_console_token = {
      key = "crowdsec/console_token";
      mode = "0400";
      owner = config.users.users.crowdsec.name or "nobody";
      group = config.users.users.crowdsec.group or "nogroup";
      restartUnits = [ "crowdsec.service" ];
    };
    crowdsec_vps_machine_password = {
      sopsFile = "${secretspath}/server/secrets.yaml";
      key = "crowdsec/vps_machine_password";
      mode = "0400";
      restartUnits = [ "crowdsec.service" ];
    };
    crowdsec_vps_bouncer_key = {
      sopsFile = "${secretspath}/server/secrets.yaml";
      key = "crowdsec/vps_bouncer_key";
      mode = "0400";
      restartUnits = [ "crowdsec.service" ];
    };
  };
}
