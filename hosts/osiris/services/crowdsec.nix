{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib.lists) optionals singleton;
  inherit (lib.meta) getExe getExe';
  inherit (lib.modules) mkForce mkIf;
  secretspath = "${inputs.my-secrets}";
  cscliExe = getExe' config.services.crowdsec.package "cscli";
  grepExe = getExe pkgs.gnugrep;
  jqExe = getExe pkgs.jq;
  run0Exe = getExe' config.systemd.package "run0";
in
{
  environment = {
    etc."crowdsec/config.yaml".source =
      (pkgs.formats.yaml { }).generate "crowdsec.yaml"
        config.services.crowdsec.settings.general;

    etc."crowdsec/capi-whitelists.yaml".text = /* yaml */ ''
      cidrs:
        - 100.64.0.0/10
        - fd7a:115c:a1e0::/48
    '';

    # cscli must be run as crowdsec user
    shellAliases.cscli = "${run0Exe} --user crowdsec ${cscliExe}";
  };

  services = {
    crowdsec = {
      enable = true;
      autoUpdateService = true;
      name = config.networking.hostName;

      hub = {
        collections = [
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

        appSecConfigs = singleton "crowdsecurity/appsec-default";
      };

      localConfig.acquisitions = [
        {
          source = "journalctl";
          journalctl_filter = singleton "_SYSTEMD_UNIT=sshd.service";
          labels.type = "syslog";
        }
        {
          source = "journalctl";
          journalctl_filter = singleton "_SYSTEMD_UNIT=traefik.service";
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
          capi_whitelists_path = "/etc/crowdsec/capi-whitelists.yaml";
        };
      };
    };

    crowdsec-firewall-bouncer = {
      enable = true;
      registerBouncer.enable = true;
      settings = {
        insecure_skip_verify = false;
        deny_action = "DROP";
        supported_decisions_types = singleton "ban";
      };
    };
  };

  mkObservability.inactiveAlertUnits =
    optionals config.services.crowdsec.enable (singleton config.systemd.services.crowdsec.name)
    ++ optionals config.services.crowdsec-firewall-bouncer.enable (
      singleton config.systemd.services.crowdsec-firewall-bouncer.name
    );

  systemd.services = {
    traefik = {
      after = mkIf config.services.traefik.enable (singleton "crowdsec.service");
      wants = mkIf config.services.traefik.enable (singleton "crowdsec.service");
    };

    crowdsec =
      let
        vpsHostname = "anubis";
      in
      {
        serviceConfig = {
          DynamicUser = mkForce false;
          StateDirectory = "crowdsec";
        };
        postStart = /* bash */ ''
          export USER=${config.users.users.crowdsec.name}
          CSCLI="/run/current-system/sw/bin/cscli"

          if ! $CSCLI console status --output raw | ${grepExe} --quiet "true"; then
            $CSCLI console enroll "$(< ${config.sops.secrets.crowdsec_console_token.path})" --name ${config.services.crowdsec.name}
          fi

          # INJECT VPS AGENT (ANUBIS)
          if ! $CSCLI machines list --output json | ${jqExe} --exit-status '.[] | select(.machineId == "${vpsHostname}")' > /dev/null; then
             $CSCLI machines add ${vpsHostname} --password "$(< ${config.sops.secrets.crowdsec_vps_machine_password.path})" -f - > /dev/null
          fi

          # INJECT VPS BOUNCER
          if ! $CSCLI bouncers list --output json | ${jqExe} --exit-status '.[] | select(.name == "${vpsHostname}-bouncer")' > /dev/null; then
             $CSCLI bouncers add ${vpsHostname}-bouncer --key "$(< ${config.sops.secrets.crowdsec_vps_bouncer_key.path})"
          fi

          # INJECT TRAEFIK BOUNCER
          if ! $CSCLI bouncers list --output json | ${jqExe} --exit-status '.[] | select(.name == "traefik-bouncer")' > /dev/null; then
             $CSCLI bouncers add traefik-bouncer --key "$(< ${config.sops.secrets.crowdsec_traefik_bouncer_key.path})"
          fi

          if ! $CSCLI allowlists inspect tailnet > /dev/null 2>&1; then
            $CSCLI allowlists create tailnet --description "Authenticated Tailscale peers"
          fi

          $CSCLI allowlists add tailnet 100.64.0.0/10 || true
          $CSCLI allowlists add tailnet fd7a:115c:a1e0::/48 || true
        '';
      };

    crowdsec-update-hub.serviceConfig.DynamicUser = mkForce false;
    crowdsec-firewall-bouncer = {
      startLimitIntervalSec = mkForce 0;
      serviceConfig = {
        DynamicUser = mkForce false;
        Restart = "always";
        RestartSec = "30s";
      };
    };
    crowdsec-firewall-bouncer-register.serviceConfig.DynamicUser = mkForce false;
  };

  mkTraefikServices.crowdsec = {
    host = "127.0.0.1";
    port = 8420;
    chain = singleton "chain-tailscale";
  };

  sops.secrets = {
    crowdsec_console_token = {
      key = "crowdsec/console_token";
      mode = "0400";
      owner = config.users.users.crowdsec.name;
      restartUnits = singleton "crowdsec.service";
    };
    crowdsec_vps_machine_password = {
      sopsFile = "${secretspath}/server/secrets.yaml";
      key = "crowdsec/vps_machine_password";
      mode = "0400";
      owner = config.users.users.crowdsec.name;
      restartUnits = singleton "crowdsec.service";
    };
    crowdsec_vps_bouncer_key = {
      sopsFile = "${secretspath}/server/secrets.yaml";
      key = "crowdsec/vps_bouncer_key";
      mode = "0400";
      owner = config.users.users.crowdsec.name;
      restartUnits = singleton "crowdsec.service";
    };
  };
}
