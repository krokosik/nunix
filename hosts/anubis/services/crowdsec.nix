{
  config,
  lib,
  inputs,
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
      "crowdsecurity/haproxy"
      "crowdsecurity/linux"
      "crowdsecurity/http-cve"
      "crowdsecurity/base-http-scenarios"
      "crowdsecurity/whitelist-good-actors"
    ];

    localConfig.acquisitions = [
      {
        source = "journalctl";
        journalctl_filter = [ "_SYSTEMD_UNIT=sshd.service" ];
        labels.type = "syslog";
      }
      {
        source = "journalctl";
        journalctl_filter = [ "_SYSTEMD_UNIT=haproxy.service" ];
        labels.type = "haproxy";
      }
    ];

    settings = {
      general.api.server.enable = false;
      lapi.credentialsFile = "/run/credentials/crowdsec.service/lapi_credentials.yaml";
    };
  };

  services.crowdsec-firewall-bouncer = {
    enable = true;
    # LAPI lives on osiris, so we authenticate via apiKeyPath instead of
    # auto-registering against a local crowdsec service.
    registerBouncer.enable = lib.mkForce false;
    secrets.apiKeyPath = config.sops.secrets.crowdsec_vps_bouncer_key.path;
    settings = {
      api_url = "https://crowdsec.${config.privateDomain}/";
      insecure_skip_verify = false;
      deny_action = "DROP";
      supported_decisions_types = [ "ban" ];
    };
  };

  systemd.services.crowdsec.serviceConfig.LoadCredential = [
    "lapi_credentials.yaml:${config.sops.templates."lapi_credentials.yaml".path}"
  ];

  sops.templates."lapi_credentials.yaml".content = ''
    url: https://crowdsec.${config.privateDomain}/
    login: ${config.services.crowdsec.name}
    password: ${config.sops.placeholder.crowdsec_vps_machine_password}
  '';

  sops.secrets = {
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
      restartUnits = [ "crowdsec-firewall-bouncer.service" ];
    };
  };
}
