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
    seerr_api_key.key = "seerr/api_key";
    wireguard_conf.key = "wireguard_conf";
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

    recyclarr = {
      enable = true;
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
          mutable = false;
          policy.isAdministrator = true;
          password._secret = config.sops.secrets.jellyfin_admin_password.path;
        };
      };
      encoding = {
        hardwareAccelerationType = "qsv";
      };
      network = {
        enableIPv6 = true;
      };
    };

    seerr = {
      enable = true;
      apiKey._secret = config.sops.secrets.seerr_api_key.path;
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
      serverConfig = {
        LegalNotice.Accepted = true;
        Preferences.WebUI = {
          Username = config.username;
          # nix run git+https://codeberg.org/feathecutie/qbittorrent_password -- -p <password>
          Password_PBKDF2 = "@ByteArray(X40XKnKuYSm50LTp9nE74A==:1R5R+rjx0PZ++yfIrvBqGMQPPzx96E9oi9SzrlWjVm5nSoaSVhL30uoCKrtwDRT8h1ZcWdkb2bLr71I9gbDjxg==)";
        };
      };
    };

    downloadarr = {
      enable = true;
      qbittorrent.enable = true;
    };
  };

  myTraefikServices = {
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
  };
}
