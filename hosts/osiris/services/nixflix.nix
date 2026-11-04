{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib.attrsets) genAttrs optionalAttrs;
  inherit (lib.lists) optionals singleton;
  inherit (lib.meta) getExe getExe';
  inherit (lib.modules) mkIf;
  inherit (lib.strings) optionalString substring toUpper;
  curlExe = getExe pkgs.curl;
  grepExe = getExe pkgs.gnugrep;
  ipExe = getExe' pkgs.iproute2 "ip";
  natpmpcExe = getExe pkgs.libnatpmp;
  oidc = config.mkAuthentik.oidcApps.jellyfin;
in
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
    nixflix_wireguard_conf.key = "wireguard/nixflix_conf";
    opensubtitles_password.key = "opensubtitles/password";
  };

  nixflix = {
    enable = true;
    mediaDir = "/srv/media";
    downloadsDir = "${config.nixflix.mediaDir}/downloads";
    mediaUsers = singleton config.username;

    theme = {
      enable = true;
      name = "onedark";
    };

    postgres.enable = true;

    sonarr = {
      enable = true;
      config = {
        apiKey._secret = config.sops.secrets.sonarr_api_key.path;

        hostConfig = {
          authenticationMethod = "basic";
          password._secret = config.sops.secrets.sonarr_password.path;
        };
      };
    };

    radarr = {
      enable = true;
      config = {
        apiKey._secret = config.sops.secrets.radarr_api_key.path;

        hostConfig = {
          authenticationMethod = "external";
          password._secret = config.sops.secrets.radarr_password.path;
        };
      };
    };

    prowlarr = {
      enable = true;
      config = {
        apiKey._secret = config.sops.secrets.prowlarr_api_key.path;

        hostConfig = {
          authenticationMethod = "external";
          password._secret = config.sops.secrets.prowlarr_password.path;
        };
        indexers = singleton {
          enable = true;
          name = "The Pirate Bay";
          apiurl = "apibay.org";
        };
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
        "SSO-OIDC-Authentication" = {
          enable = true;
          # The Jellyfin 10.11-compatible release reports a different API name.
          apiName = "SSO-OIDC Authentication";
          config = {
            DefaultProvider = "authentik";
            AutoCreateUsers = true;
            # Reuse existing accounts and watch history on their first OIDC login.
            MigrateLocalUsers = true;
            SyncDisplayName = false;
            DefaultRoleName = "";
            Providers = singleton {
              ProviderId = "authentik";
              DisplayName = "Authentik";
              Enabled = true;
              Authority = oidc.issuerUrl;
              ClientId._secret = config.sops.secrets.${oidc.credentials.clientId.secretName}.path;
              ClientSecret._secret = config.sops.secrets.${oidc.credentials.clientSecret.secretName}.path;
              ServerBaseUrl = config.mkTraefikServices.jellyfin.fullHostname;
              Scopes = "openid profile email";
              RoleClaim = "groups";
              UsernameClaim = "preferred_username";
              ButtonColor = "#fd4b2d";
              SyncProfileImage = false;
              StrictAccessTokenValidation = true;
            };
            RoleMappings =
              map
                (role: {
                  RoleName = role;
                  ProviderFilter = "authentik";
                  IsAdmin = role == "admins";
                  Priority = if role == "admins" then 100 else 50;
                  EnableAllLibraries = true;
                  EnableMediaPlayback = true;
                  EnableRemoteAccess = true;
                  EnableTranscoding = true;
                  EnableContentDeletion = false;
                })
                [
                  "admins"
                  oidc.accessGroup
                ];
          };
        };

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

      # TODO: On Jellyfin 12, migrate this to OIDC plugin 2.x automatic branding.
      branding = {
        # A form avoids Jellyfin rewriting anchors into differently styled link buttons.
        # Keep the HTML on one line so Markdown does not escape it or wrap it in a paragraph.
        loginDisclaimer = /* html */ ''
          <div class="readOnlyContent"><form action="/sso/OIDC/Start/authentik" method="get"><button is="emby-button" type="submit" class="raised button-submit block emby-button" style="background: #fd4b2d !important;"><span>Sign in with Authentik</span></button></form></div>
        '';

        # Preserve Nixflix's theme import when extending the default branding CSS.
        customCss =
          optionalString config.nixflix.theme.enable /* css */ ''
            @import url("https://theme-park.dev/css/base/jellyfin/${config.nixflix.theme.name}.css");
          ''
          + /* css */ ''
            #loginPage .loginDisclaimer {
              width: 100%;
            }
          '';
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
      wgConfFile = config.sops.secrets.nixflix_wireguard_conf.path;
      accessibleFrom = [
        "192.168.1.0/24"
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

  mkObservability.inactiveAlertUnits = mkIf config.nixflix.enable (
    optionals config.nixflix.sonarr.enable (singleton config.systemd.services.sonarr.name)
    ++ optionals config.nixflix.radarr.enable (singleton config.systemd.services.radarr.name)
    ++ optionals config.nixflix.prowlarr.enable (singleton config.systemd.services.prowlarr.name)
    ++ optionals config.nixflix.flaresolverr.enable (
      singleton config.systemd.services.flaresolverr.name
    )
    ++ optionals config.nixflix.jellyfin.enable (singleton config.systemd.services.jellyfin.name)
    ++ optionals config.nixflix.seerr.enable (singleton config.systemd.services.seerr.name)
    ++ optionals config.nixflix.torrentClients.qbittorrent.enable (
      singleton config.systemd.services.qbittorrent.name
    )
    ++ optionals config.nixflix.maintainerr.enable (singleton config.systemd.services.maintainerr.name)
  );

  mkAuthentik = {
    launcherApps.seerr = {
      displayName = "Seerr";
      displayGroup = "Apps";
      accessGroup = "family";
      launchUrl = config.mkTraefikServices.seerr.fullHostname;
    };

    oidcApps.jellyfin = {
      displayName = "Jellyfin";
      displayGroup = "Apps";
      accessGroup = "family";
      launchUrl = "${config.mkTraefikServices.jellyfin.fullHostname}/sso/OIDC/Start/authentik";
      redirectUris = singleton "${config.mkTraefikServices.jellyfin.fullHostname}/sso/OIDC/Callback/authentik";
    };

    forwardAuthApps =
      (genAttrs
        [
          "sonarr"
          "radarr"
          "prowlarr"
        ]
        (
          name:
          {
            displayName = toUpper (substring 0 1 name) + substring 1 (-1) name;
            displayGroup = "Arr";
            accessGroup = "admins";
          }
          // optionalAttrs (name == "sonarr") {
            basicAuth = {
              username = config.nixflix.sonarr.config.hostConfig.username;
              passwordSecretName = "sonarr_password";
            };
          }
        )
      )
      // {
        # The WebUI stays password-protected when accessed directly; the
        # proxy enforces the admins policy for the qbit hostname.
        qbittorrent = {
          displayName = "qBittorrent";
          displayGroup = "Arr";
          accessGroup = "admins";
          iconUrl = "https://raw.githubusercontent.com/homarr-labs/dashboard-icons/main/png/qbittorrent.png";
          host = config.mkTraefikServices.qbittorrent.fullHostname;
        };
      };
  };

  mkTraefikServices = {
    sonarr = {
      port = config.nixflix.sonarr.settings.server.port;
    };
    radarr = {
      port = config.nixflix.radarr.settings.server.port;
    };
    prowlarr = {
      port = config.nixflix.prowlarr.settings.server.port;
    };
    jellyfin = {
      public = true;
      port = config.nixflix.jellyfin.network.publicHttpPort;
      chain = singleton "chain-no-auth";
    };
    seerr = {
      public = true;
      port = config.nixflix.seerr.port;
      chain = singleton "chain-no-auth";
    };
    qbittorrent = {
      host = config.nixflix.torrentClients.qbittorrent.connectionAddress;
      port = config.nixflix.torrentClients.qbittorrent.webuiPort;
      subdomain = "qbit";
    };
    maintainerr = {
      port = config.nixflix.maintainerr.port;
    };
  };

  # Ensure the NAT-PMP tool is available on the system
  environment.systemPackages = singleton pkgs.libnatpmp;

  systemd = {
    services = {
      sonarr.unitConfig.RequiresMountsFor = singleton config.nixflix.mediaDir;
      radarr.unitConfig.RequiresMountsFor = singleton config.nixflix.mediaDir;
      jellyfin.unitConfig.RequiresMountsFor = singleton config.nixflix.mediaDir;
      qbittorrent.unitConfig.RequiresMountsFor = singleton config.nixflix.mediaDir;
      maintainerr.unitConfig.RequiresMountsFor = singleton config.nixflix.mediaDir;

      # vpn-confinement's wg-down deletes the namespace on a failed start but
      # cannot remove nonempty NAT chains. Clear those orphaned chains before
      # retrying, without touching unrelated iptables-nft or Docker rules.
      wg.serviceConfig.ExecStartPre = getExe (
        pkgs.writeShellApplication {
          name = "cleanup-stale-wg-nat";
          runtimeInputs = with pkgs; [
            iproute2
            iptables
          ];
          text = /* bash */ ''
            if ip netns list | ${getExe pkgs.gnugrep} --quiet '^wg\([[:space:]]\|$\)'; then
              exit 0
            fi

            for tool in iptables ip6tables; do
              for chain in wg-prerouting wg-postrouting; do
                if "$tool" --table nat --list-rules "$chain" >/dev/null 2>&1; then
                  for parent in PREROUTING POSTROUTING; do
                    while "$tool" --table nat --check "$parent" --jump "$chain" 2>/dev/null; do
                      "$tool" --table nat --delete "$parent" --jump "$chain"
                    done
                  done

                  "$tool" --table nat --flush "$chain"
                  "$tool" --table nat --delete-chain "$chain"
                fi
              done
            done
          '';
        }
      );

      proton-port-forward = {
        description = "ProtonVPN Port Forwarding to qBittorrent";
        after = [
          "wg.service"
          "qbittorrent.service"
        ];
        wants = singleton "wg.service";

        serviceConfig = {
          Type = "oneshot";
        };

        script = /* bash */ ''
          GATEWAY="10.2.0.1"
          NETNS="wg"
          QBIT_URL="http://${config.nixflix.torrentClients.qbittorrent.connectionAddress}:${toString config.nixflix.torrentClients.qbittorrent.webuiPort}"

          # 1. Inject the specific route for ProtonVPN's NAT-PMP gateway
          # We use 'replace' so it doesn't fail if the route already exists from a previous run
          ${ipExe} netns exec $NETNS ${ipExe} route replace $GATEWAY/32 dev wg0

          # 2. Authenticate securely: curl reads the password directly from the SOPS file
          ${curlExe} --silent --cookie-jar /tmp/qbit_cookie.txt \
            --data-urlencode "username=${config.username}" \
            --data-urlencode "password@${config.sops.secrets.qbittorrent_password.path}" \
            "$QBIT_URL/api/v2/auth/login"

          # 3. Request UDP and TCP port mappings from ProtonVPN
          TCP_OUT=$(${ipExe} netns exec $NETNS ${natpmpcExe} -a 1 0 tcp 60 -g $GATEWAY)

          # 4. Extract the mapped public port
          PORT=$(echo "$TCP_OUT" | ${grepExe} --only-matching --perl-regexp 'Mapped public port \K\d+')

          if [ -n "$PORT" ]; then
            echo "Successfully mapped ProtonVPN port: $PORT"
            
            # 5. Push the new port to qBittorrent using the session cookie
            ${curlExe} --silent --cookie /tmp/qbit_cookie.txt --request POST "$QBIT_URL/api/v2/app/setPreferences" \
              --data "json={\"listen_port\": $PORT}"
          else
            echo "Failed to acquire port from ProtonVPN."
            exit 1
          fi

          # Clean up the cookie
          rm --force /tmp/qbit_cookie.txt
        '';
      };
    };

    # Timer to fire the script every 45 seconds to keep the 60-second lease alive
    timers.proton-port-forward = {
      description = "Timer for ProtonVPN Port Forwarding";
      wantedBy = singleton "timers.target";
      timerConfig = {
        OnBootSec = "1min";
        OnUnitActiveSec = "45s";
      };
    };
  };
}
