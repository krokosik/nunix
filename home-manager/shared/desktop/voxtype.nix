{
  inputs,
  osConfig,
  pkgs,
  ...
}:
let
  useVulkan = osConfig.hardware.nvidia.enabled;
  voxtypePackages = inputs.voxtype.packages.${pkgs.stdenv.hostPlatform.system};
in
{
  imports = [ inputs.voxtype.homeManagerModules.default ];

  config.programs.voxtype = {
    enable = true;
    engine = "whisper";
    package = if useVulkan then voxtypePackages.vulkan else voxtypePackages.default;
    model.name = if useVulkan then "large-v3-turbo" else "medium.en";
    service.enable = true;

    settings = {
      state_file = "auto";

      # Use notifications and audio feedback without a separate OSD frontend.
      osd.enabled = false;

      hotkey = {
        enabled = true;
        key = "SCROLLLOCK";
        mode = "push_to_talk";
        modifiers = [ ];
      };
      audio = {
        device = "default";
        max_duration_secs = 60;
        sample_rate = 16000;
        feedback.enabled = true;
      };
      whisper = {
        language = "en";
        translate = false;
      };
      output = {
        fallback_to_clipboard = true;
        mode = "type";
        type_delay_ms = 0;
        notification = {
          on_recording_start = true;
          on_recording_stop = true;
          on_transcription = false;
          on_no_speech = true;
        };
      };
    };
  };
}
