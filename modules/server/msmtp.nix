{
  config,
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
}
