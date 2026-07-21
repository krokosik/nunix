{
  config,
  lib,
  pkgs,
  ...
}:
{
  users.groups.msmtp = { };

  environment.etc."aliases".text = ''
    root: ${config.systemEmail}
    postmaster: root
    abuse: root
  '';

  sops.secrets.smtp_token = {
    key = "proton/smtp_token";
    mode = "0400";
  };

  programs.msmtp = {
    enable = true;
    setSendmail = true;
    defaults = {
      aliases = "/etc/aliases";
      port = 587;
      tls_trust_file = "/etc/ssl/certs/ca-certificates.crt";
      tls = true;
      auth = "login";
      tls_starttls = true;
    };
    accounts = {
      default = {
        host = "smtp.protonmail.ch";
        passwordeval = "cat /run/credentials/msmtp.service/smtp_token";
        user = "${config.networking.hostName}@${config.publicDomain}";
        from = "${config.networking.hostName}@${config.publicDomain}";
      };
    };
  };

  systemd.services.msmtp.serviceConfig.LoadCredential = [
    "smtp_token:${config.sops.secrets.smtp_token.path}"
  ];

  # Local SMTP listener for apps that speak SMTP (e.g. authentik). Forwards
  # to the protonmail relay configured above via the same `programs.msmtp`
  # config + sops secret. Bind to 127.0.0.1 only — never expose.
  systemd.services.msmtpd = {
    description = "Local SMTP relay (msmtpd → protonmail)";
    after = [ "sops-install-secrets.service" ];
    wants = [ "sops-install-secrets.service" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "simple";
      ExecStart = "${lib.getExe pkgs.msmtp} --daemon --listen=127.0.0.1:2500";
      Restart = "on-failure";
      LoadCredential = [ "smtp_token:${config.sops.secrets.smtp_token.path}" ];
    };
  };
}
