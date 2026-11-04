{
  config,
  pkgs,
  lib,
  ...
}:
let
  inherit (lib.lists) singleton;
  inherit (lib.meta) getExe getExe';
  inherit (lib.modules) mkIf;
  curlExe = getExe pkgs.curl;
  statExe = getExe' pkgs.coreutils "stat";
  unzipExe = getExe pkgs.unzip;
in
mkIf config.services.traefik.enable {
  # 1. TEMPLATE THE IP2LOCATION DOWNLOAD TOKEN FOR SYSTEMD
  sops = {
    templates."ip2location.env".content = /* bash */ ''
      IP2LOCATION_TOKEN=${config.sops.placeholder.ip2location_token}
    '';

    secrets.ip2location_token = {
      key = "ip2location/token";
      mode = "0400";
    };
  };

  # 2. THE FETCHER SERVICE
  systemd = {
    services.update-ip2location = {
      description = "Update IP2Location Database for Traefik";
      after = singleton "network-online.target";
      wants = singleton "network-online.target";
      before = singleton "traefik.service";

      serviceConfig = {
        Type = "oneshot";
        User = config.users.users.traefik.name;
        Group = config.users.users.traefik.group;
        StateDirectory = "traefik/plugins-storage";
        EnvironmentFile = config.sops.templates."ip2location.env".path;
      };

      script = /* bash */ ''
        cd /var/lib/traefik/plugins-storage

        # Download the zipped database
        ${curlExe} --location --silent --output db.zip "https://www.ip2location.com/download?token=''${IP2LOCATION_TOKEN}&file=DB1LITEBINIPV6"

        # Safety Check: If the file is under 100KB, it's a text error, not a database.
        if [ $(${statExe} --format=%s db.zip) -lt 102400 ]; then
          echo "IP2Location Error: Download failed or rate-limited. Server returned:"
          cat db.zip
          rm db.zip
          exit 0
        fi

        ${unzipExe} -o db.zip IP2LOCATION-LITE-DB1.IPV6.BIN
        rm db.zip
      '';
    };

    timers.update-ip2location = {
      description = "Weekly update of IP2Location Database";
      wantedBy = singleton "timers.target";
      timerConfig = {
        OnCalendar = "weekly";
        Persistent = true;
      };
    };
  };
}
