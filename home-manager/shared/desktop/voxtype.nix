{
  inputs,
  osConfig,
  pkgs,
  ...
}:
let
  useVulkan = osConfig.hardware.nvidia.enabled;
  voxtypePackages = pkgs.unstable;
in
{
  imports = [ inputs.voxtype.homeManagerModules.default ];

  config.programs.voxtype = {
    enable = true;
    engine = "whisper";
    package = if useVulkan then voxtypePackages.voxtype-vulkan else voxtypePackages.voxtype-onnx;
    service.enable = true;

    settings = {
      state_file = "auto";
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
      };
      whisper = {
        language = "en";
        model = if useVulkan then "large-v3-turbo" else "medium.en";
        translate = false;
      };
      output = {
        fallback_to_clipboard = true;
        mode = "type";
        type_delay_ms = 0;
        notification = {
          on_recording_start = false;
          on_recording_stop = false;
          on_transcription = true;
        };
      };
    };
  };
}
