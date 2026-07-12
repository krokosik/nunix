{
  config,
  pkgs,
  lib,
  ...
}:
lib.mkIf config.services.traefik.enable {
  # 1. Template the IP2Location Download Token for systemd
  sops.templates."ip2location.env".content = ''
    IP2LOCATION_TOKEN=${config.sops.placeholder.ip2location_token}
  '';

  sops.secrets.ip2location_token = {
    key = "ip2location/token";
    mode = "0400";
  };

  # 2. The Fetcher Service
  systemd.services.update-ip2location = {
    description = "Update IP2Location Database for Traefik";
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    before = [ "traefik.service" ];

    serviceConfig = {
      Type = "oneshot";
      User = config.users.users.traefik.name;
      Group = config.users.users.traefik.group;
      StateDirectory = "traefik/plugins-storage";
      EnvironmentFile = config.sops.templates."ip2location.env".path;
    };

    script = ''
      cd /var/lib/traefik/plugins-storage

      # Download the zipped database
      ${pkgs.curl}/bin/curl -L -s -o db.zip "https://www.ip2location.com/download?token=''${IP2LOCATION_TOKEN}&file=DB1LITEBINIPV6"

      # Safety Check: If the file is under 100KB, it's a text error, not a database.
      if [ $(${pkgs.coreutils}/bin/stat -c%s db.zip) -lt 102400 ]; then
        echo "IP2Location Error: Download failed or rate-limited. Server returned:"
        cat db.zip
        rm db.zip
        exit 0
      fi

      ${pkgs.unzip}/bin/unzip -o db.zip IP2LOCATION-LITE-DB1.IPV6.BIN
      rm db.zip
    '';
  };

  systemd.timers.update-ip2location = {
    description = "Weekly update of IP2Location Database";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "weekly";
      Persistent = true;
    };
  };
}
