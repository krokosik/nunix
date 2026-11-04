{
  config,
  inputs,
  lib,
  osConfig,
  pkgs,
  ...
}:
let
  inherit (lib.lists) singleton;
  voxtypePackages = inputs.voxtype.packages.${pkgs.stdenv.hostPlatform.system};
in
{
  imports = singleton inputs.voxtype.homeManagerModules.default;

  config = {
    programs.voxtype = {
      enable = true;
      engine = "whisper";
      package =
        if osConfig.hardware.graphics.enable then voxtypePackages.vulkan else voxtypePackages.default;
      model.name = if osConfig.hardware.nvidia.enabled then "large-v3-turbo" else "medium";
      service.enable = true;

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
    };

    # Restart the daemon when its generated configuration changes.
    systemd.user.services.voxtype.Unit.X-Restart-Triggers =
      singleton "${config.xdg.configFile."voxtype/config.toml".source}";
  };
}
