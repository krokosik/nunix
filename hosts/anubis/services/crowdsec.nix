{
  config,
  lib,
  inputs,
  ...
}:
let
  secretspath = builtins.toString inputs.my-secrets;
in
{
  services.crowdsec = {
    enable = true;
    autoUpdateService = true;
    name = "anubis";

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
      lapi.credentialsFile = config.sops.secrets.crowdsec_lapi.path;
    };
  };

  services.crowdsec-firewall-bouncer = {
    enable = true;
    # LAPI lives on osiris, so we authenticate via apiKeyPath instead of
    # auto-registering against a local crowdsec service.
    registerBouncer.enable = lib.mkForce false;
    secrets.apiKeyPath = config.sops.secrets.crowdsec_bouncer_key.path;
    settings = {
      api_url = "https://crowdsec.ts.krokosik.com/";
      insecure_skip_verify = false;
      deny_action = "DROP";
      supported_decisions_types = [ "ban" ];
    };
  };

  # The upstream module sets DynamicUser=true, which assigns a random UID
  # per boot. We override to false so the named `crowdsec` system user can
  # read the sops-owned local_api_credentials.yaml file directly.
  systemd.services.crowdsec.serviceConfig.DynamicUser = lib.mkForce false;

  sops.secrets = {
    crowdsec_lapi = {
      sopsFile = "${secretspath}/anubis/crowdsec-lapi.yaml";
      format = "binary";
      owner = config.services.crowdsec.user;
      group = config.services.crowdsec.group;
      mode = "0400";
      restartUnits = [ "crowdsec.service" ];
    };
    crowdsec_bouncer_key = {
      sopsFile = "${secretspath}/anubis/secrets.yaml";
      key = "crowdsec_bouncer_key";
      mode = "0440";
      restartUnits = [ "crowdsec-firewall-bouncer.service" ];
    };
  };
}
