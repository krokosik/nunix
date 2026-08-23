{ config, pkgs, ... }:
{
  sops.secrets = {
    sonarr_api_key.key = "sonarr/api_key";
    sonarr_password.key = "sonarr/password";
    radarr_api_key.key = "radarr/api_key";
    radarr_password.key = "radarr/password";
    prowlarr_api_key.key = "prowlarr/api_key";
    prowlarr_password.key = "prowlarr/password";
    jellyfin_admin_password.key = "jellyfin/password";
    jellyfin_api_key.key = "jellyfin/api_key";
    qbittorrent_password.key = "qbittorrent/password";
    seerr_api_key.key = "seerr/api_key";
    wireguard_conf.key = "wireguard_conf";
    opensubtitles_password.key = "opensubtitles/password";
  };

  nixflix = {
    enable = true;
    mediaDir = "/srv/media";
    mediaUsers = [ config.username ];

    theme = {
      enable = true;
      name = "onedark";
    };

    postgres.enable = true;

    sonarr = {
      enable = true;
      config = {
        apiKey._secret = config.sops.secrets.sonarr_api_key.path;
        hostConfig.password._secret = config.sops.secrets.sonarr_password.path;
      };
    };

    radarr = {
      enable = true;
      config = {
        apiKey._secret = config.sops.secrets.radarr_api_key.path;
        hostConfig.password._secret = config.sops.secrets.radarr_password.path;
      };
    };

    prowlarr = {
      enable = true;
      config = {
        apiKey._secret = config.sops.secrets.prowlarr_api_key.path;
        hostConfig.password._secret = config.sops.secrets.prowlarr_password.path;
        indexers = [
          {
            enable = true;
            name = "The Pirate Bay";
            apiurl = "apibay.org";
          }
        ];
      };
    };

    flaresolverr.enable = true;

    jellyfin = {
      enable = true;
      apiKey._secret = config.sops.secrets.jellyfin_api_key.path;
      users = {
        "${config.username}" = {
          mutable = true;
          policy.isAdministrator = true;
          password._secret = config.sops.secrets.jellyfin_admin_password.path;
        };
      };
      encoding = {
        # https://jellyfin.org/docs/general/administration/hardware-acceleration/
        hardwareAccelerationType = "qsv";
        allowHevcEncoding = true;
        # https://jellyfin.org/docs/general/administration/hardware-acceleration/intel/#configure-and-verify-lp-mode-on-linux
        enableIntelLowPowerH264HwEncoder = false;
        enableIntelLowPowerHevcHwEncoder = false;
      };
      network = {
        enableIPv6 = true;
      };
      system = {
        enableMetrics = false;
        metadataCountryCode = "PL";
      };
      plugins = {
        "Open Subtitles" = {
          enable = true;
          config = {
            Username = "krokosik";
            Password._secret = config.sops.secrets.opensubtitles_password.path;
          };
        };

        "Subtitle Extract" = {
          enable = true;
          config.ExtractionDuringLibraryScan = true;
        };
      };

      libraries =
        let
          subtitleSettings = {
            subtitleDownloadLanguages = [
              "eng"
              "pol"
            ];
            saveSubtitlesWithMedia = true;
            allowEmbeddedSubtitles = "AllowAll";
            requirePerfectSubtitleMatch = true;
            skipSubtitlesIfAudioTrackMatches = false;
            skipSubtitlesIfEmbeddedSubtitlesPresent = true;
          };
        in
        {
          Shows = subtitleSettings;
          Movies = subtitleSettings;
        };
    };

    seerr = {
      enable = true;
      apiKey._secret = config.sops.secrets.seerr_api_key.path;
      jellyfin.externalHostname = config.mkTraefikServices.jellyfin.fullHostname;
      # radarr.Radarr.externalUrl = config.mkTraefikServices.radarr.fullHostname;
      # radarr.Sonarr.externalUrl = config.mkTraefikServices.sonarr.fullHostname;
      settings.users = {
        localLogin = false;
        newPlexLogin = false;
        defaultPermissions = 5;
      };
    };

    vpn = {
      enable = true;
      wgConfFile = config.sops.secrets.wireguard_conf.path;
      accessibleFrom = [
        "192.168.0.0/24"
        "127.0.0.0/8"
        "10.0.0.0/8"
      ];
    };

    torrentClients.qbittorrent = {
      enable = true;
      vpn.enable = true;
      password._secret = config.sops.secrets.qbittorrent_password.path;
      serverConfig = {
        LegalNotice.Accepted = true;
        Preferences.WebUI = {
          Username = config.username;
          # nix run git+https://codeberg.org/feathecutie/qbittorrent_password -- -p <password>
          Password_PBKDF2 = "@ByteArray(zSiUF/IfzUjMGRs9AoMx7w==:Gmn3y62e6Md7R/Cjn9P5CDiVKBB4YrCXtGa+lHpV8rytNcOn097rUbpMJ32z/LVOdJVBPc233/QztLzY871zfQ==)";
        };
      };
    };

    maintainerr = {
      enable = true;
    };

    recyclarr = {
      enable = false;
    };
  };

  mkTraefikServices = {
    sonarr = {
      port = config.nixflix.sonarr.settings.server.port;
      chain = [ "chain-no-auth" ];
    };
    radarr = {
      port = config.nixflix.radarr.settings.server.port;
      chain = [ "chain-no-auth" ];
    };
    prowlarr = {
      port = config.nixflix.prowlarr.settings.server.port;
      chain = [ "chain-no-auth" ];
    };
    jellyfin = {
      public = true;
      port = config.nixflix.jellyfin.network.publicHttpPort;
      chain = [ "chain-no-auth" ];
    };
    seerr = {
      public = true;
      port = config.nixflix.seerr.port;
      chain = [ "chain-no-auth" ];
    };
    qbittorrent = {
      host = config.nixflix.torrentClients.qbittorrent.connectionAddress;
      port = config.nixflix.torrentClients.qbittorrent.webuiPort;
      chain = [ "chain-no-auth" ];
      subdomain = "qbit";
    };
    maintainerr = {
      port = config.nixflix.maintainerr.port;
    };
  };

  # Ensure the NAT-PMP tool is available on the system
  environment.systemPackages = [ pkgs.libnatpmp ];

  systemd.services.proton-port-forward = {
    description = "ProtonVPN Port Forwarding to qBittorrent";
    after = [
      "wg.service"
      "qbittorrent.service"
    ];
    wants = [ "wg.service" ];

    serviceConfig = {
      Type = "oneshot";
    };

    script = ''
      GATEWAY="10.2.0.1"
      NETNS="wg"
      QBIT_URL="http://${config.nixflix.torrentClients.qbittorrent.connectionAddress}:${toString config.nixflix.torrentClients.qbittorrent.webuiPort}"

      # 1. Inject the specific route for ProtonVPN's NAT-PMP gateway
      # We use 'replace' so it doesn't fail if the route already exists from a previous run
      ${pkgs.iproute2}/bin/ip netns exec $NETNS ${pkgs.iproute2}/bin/ip route replace $GATEWAY/32 dev wg0

      # 2. Authenticate securely: curl reads the password directly from the SOPS file
      ${pkgs.curl}/bin/curl -s -c /tmp/qbit_cookie.txt \
        --data-urlencode "username=${config.username}" \
        --data-urlencode "password@${config.sops.secrets.qbittorrent_password.path}" \
        "$QBIT_URL/api/v2/auth/login"

      # 3. Request UDP and TCP port mappings from ProtonVPN
      TCP_OUT=$(${pkgs.iproute2}/bin/ip netns exec $NETNS ${pkgs.libnatpmp}/bin/natpmpc -a 1 0 tcp 60 -g $GATEWAY)

      # 4. Extract the mapped public port
      PORT=$(echo "$TCP_OUT" | ${pkgs.gnugrep}/bin/grep -oP 'Mapped public port \K\d+')

      if [ -n "$PORT" ]; then
        echo "Successfully mapped ProtonVPN port: $PORT"
        
        # 5. Push the new port to qBittorrent using the session cookie
        ${pkgs.curl}/bin/curl -s -b /tmp/qbit_cookie.txt -X POST "$QBIT_URL/api/v2/app/setPreferences" \
          -d "json={\"listen_port\": $PORT}"
      else
        echo "Failed to acquire port from ProtonVPN."
        exit 1
      fi

      # Clean up the cookie
      rm -f /tmp/qbit_cookie.txt
    '';
  };

  # Timer to fire the script every 45 seconds to keep the 60-second lease alive
  systemd.timers.proton-port-forward = {
    description = "Timer for ProtonVPN Port Forwarding";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "1min";
      OnUnitActiveSec = "45s";
    };
  };
}
