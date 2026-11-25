{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib.attrsets) recursiveUpdate;
  inherit (lib.lists) singleton;
  inherit (lib.meta) getExe getExe';
  inherit (lib.modules) mkForce mkIf;
  inherit (lib.options) mkEnableOption mkOption;
  inherit (lib.strings) escapeShellArgs;
  inherit (lib.trivial) importTOML;
  inherit (lib.types) listOf port str;

  cfg = config.nunix.voxtype;
  osConfig = config;
  serverIp = config.nunix.hosts.${cfg.server.host}.tailscale.ipv4;
  endpoint = "http://${serverIp}:${toString cfg.server.port}";

  voxtypePackages = inputs.voxtype.packages.${pkgs.stdenv.hostPlatform.system};
  modelDefinitions = import "${inputs.voxtype}/nix/models.nix";

  settings = {
    state_file = "auto";

    # DMS owns the waveform OSD.
    osd.enabled = false;

    hotkey.enabled = false;

    audio = {
      device = "default";
      max_duration_secs = 60;
      sample_rate = 16000;
      feedback.enabled = true;
    };
    whisper = {
      language = [
        "en"
        "pl"
      ];
      translate = false;
    };
    output = {
      fallback_to_clipboard = true;
      mode = "type";
      type_delay_ms = 0;
      notification = {
        on_recording_start = false;
        on_recording_stop = false;
        on_transcription = false;
        on_no_speech = true;
      };
    };
  };

  # Remote mode sends only the first language of a list, so let the server detect it.
  remoteConfig = (pkgs.formats.toml { }).generate "voxtype-remote.toml" (
    recursiveUpdate (importTOML "${inputs.voxtype}/config/default.toml") (
      recursiveUpdate settings {
        whisper = {
          mode = "remote";
          remote_endpoint = endpoint;
          language = "auto";
        };
        # whisper-server ends every segment with a newline, which voxtype would type as Enter.
        output.post_process.command = "${getExe' pkgs.coreutils "tr"} -d '\\n'";
      }
    )
  );

  client =
    { config, ... }:
    let
      voxtype = config.programs.voxtype;
    in
    {
      imports = singleton inputs.voxtype.homeManagerModules.default;

      programs.voxtype = {
        enable = true;
        engine = "whisper";
        package =
          if osConfig.hardware.graphics.enable then voxtypePackages.vulkan else voxtypePackages.default;
        model.name = if osConfig.hardware.nvidia.enabled then "large-v3-turbo" else "medium";
        service.enable = true;
        inherit settings;
      };

      # The probe picks which daemon runs: the remote one while the server is healthy, the local one otherwise.
      systemd.user = {
        services = {
          voxtype = {
            Unit = {
              Conflicts = singleton "voxtype-remote.service";
              # Restart the daemon when its generated configuration changes.
              X-Restart-Triggers = singleton "${config.xdg.configFile."voxtype/config.toml".source}";
            };
            Install.WantedBy = mkForce [ ];
          };

          voxtype-remote = {
            Unit = {
              Description = "VoxType daemon transcribing on ${cfg.server.host}";
              PartOf = singleton "graphical-session.target";
              After = [
                "graphical-session.target"
                "pipewire.service"
                "pipewire-pulse.service"
                # The ordering works in both directions: systemd stops the conflicting
                # daemon, releasing its lock, before starting the other one.
                "voxtype.service"
              ];
              Conflicts = singleton "voxtype.service";
              X-Restart-Triggers = singleton "${remoteConfig}";
            };
            Service = {
              ExecStart = "${getExe' voxtype.package "voxtype"} --config ${remoteConfig} daemon";
              Restart = "on-failure";
              RestartSec = 5;
            };
          };

          voxtype-probe = {
            Unit = {
              Description = "Select the VoxType daemon by whisper-server reachability";
              OnSuccess = singleton "voxtype-remote.service";
              OnFailure = singleton "voxtype.service";
            };
            Service = {
              Type = "oneshot";
              ExecStart = "${getExe pkgs.curl} --fail --silent --show-error --noproxy '*' --max-time 3 ${endpoint}/health";
            };
          };
        };

        timers.voxtype-probe = {
          Unit.Description = "Probe whisper-server for VoxType";
          Timer = {
            OnActiveSec = 0;
            OnUnitActiveSec = "30s";
          };
          Install.WantedBy = singleton "graphical-session.target";
        };
      };
    };
in
{
  options.nunix.voxtype.server = {
    enable = mkEnableOption "the shared whisper-server for VoxType clients";
    host = mkOption {
      type = str;
      default = "lindbladian";
      description = "Host running the whisper-server that VoxType clients prefer.";
    };
    port = mkOption {
      type = port;
      default = 18080;
      description = "Port of the whisper-server on the host's Tailscale address.";
    };
    clients = mkOption {
      type = listOf str;
      default = [
        "horus"
        "isis"
        "lindbladian"
      ];
      description = "Hosts allowed to reach the whisper-server, including the server itself.";
    };
  };

  config = {
    home-manager.sharedModules = singleton client;

    assertions = singleton {
      assertion = cfg.server.enable -> config.networking.hostName == cfg.server.host;
      message = "nunix.voxtype.server.enable must be set on nunix.voxtype.server.host (${cfg.server.host}).";
    };

    # Bind only to the server's Tailscale address, never LAN or public interfaces.
    systemd.services.whisper-server = mkIf cfg.server.enable {
      description = "GPU transcription for VoxType clients over Tailscale";
      wantedBy = singleton "multi-user.target";
      wants = singleton "tailscaled.service";
      after = singleton "tailscaled.service";
      serviceConfig = {
        ExecStart = escapeShellArgs [
          (getExe' (pkgs.whisper-cpp.override { vulkanSupport = true; }) "whisper-server")
          "--model"
          (pkgs.fetchurl { inherit (modelDefinitions.large-v3-turbo) url hash; })
          "--host"
          serverIp
          "--port"
          (toString cfg.server.port)
          "--language"
          "auto"
          # VoxType's remote mode posts to the OpenAI-compatible path.
          "--inference-path"
          "/v1/audio/transcriptions"
        ];
        Restart = "on-failure";
        RestartSec = 5;
        DynamicUser = true;
        SupplementaryGroups = [
          "render"
          "video"
        ];
        NoNewPrivileges = true;
        PrivateTmp = true;
        ProtectHome = true;
        ProtectSystem = "strict";
        IPAddressDeny = "any";
        IPAddressAllow = map (host: "${config.nunix.hosts.${host}.tailscale.ipv4}/32") cfg.server.clients;
        RestrictAddressFamilies = [
          "AF_UNIX"
          "AF_INET"
          "AF_INET6"
        ];
        UMask = "0077";
      };
    };
  };
}
