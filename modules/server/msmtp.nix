{
  config,
  ...
}:
{
  ### Msmtp
  #### Note: see vps/prometheus.nix for how to use systemd load credentials
  #### for services with DynamicUser=true so that the credential permissions can
  #### be kept at 0400
  #### Otherwise, add any service that needs access to the 'msmtp' group

  users.groups.msmtp = { };

  sops.secrets."proton/smtp-token" = {
    mode = "0440";
    group = "msmtp";
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
        passwordeval = "cat ${config.sops.secrets."proton/smtp-token".path}";
        user = "osiris@krokosik.com";
        from = "osiris@krokosik.com";
      };
    };
  };
}