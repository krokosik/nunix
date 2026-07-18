{
  config,
  pkgs,
  ...
}:
{
  services.postgresql = {
    enable = true;
    package = pkgs.postgresql_17;
    # enableTCPIP so docker containers can reach postgres via host.docker.internal
    enableTCPIP = true;
    # Docker subnets authenticate via scram-sha-256; inserted before the
    # upstream defaults (local peer, 127.0.0.1/::1 md5).
    authentication = ''
      host  all all 172.16.0.0/12    scram-sha-256
      host  all all 192.168.90.0/24  scram-sha-256
    '';
  };

  # Firewall: allow docker containers to reach postgres on the host (nftables)
  networking.firewall.extraInputRules = ''
    ip saddr 172.16.0.0/12   tcp dport 5432 accept
    ip saddr 192.168.90.0/24  tcp dport 5432 accept
  '';

  sops.secrets.postgres_default_password = {
    key = "postgresql/default/password";
    owner = config.users.users.postgres.name;
    restartUnits = [ "postgresql-setup.service" ];
  };

  systemd.services.postgresql-setup.postStart = ''
    PGPW=$(cat ${config.sops.secrets.postgres_default_password.path})
    psql -d postgres -c "ALTER USER postgres WITH PASSWORD '$PGPW';"
  '';

  # Postgres backup
  services.postgresqlBackup = {
    enable = true;
    location = "/var/backups/postgres";
    backupAll = true;
  };
}
