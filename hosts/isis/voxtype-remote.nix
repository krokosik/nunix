{
  lib,
  osConfig,
  pkgs,
  ...
}:
let
  inherit (lib.meta) getExe getExe';
  inherit (lib.modules) mkForce;
  inherit (lib.strings) fileContents;
  fallback = pkgs.writeShellApplication {
    name = "voxtype-fallback";
    runtimeInputs = with pkgs; [
      curl
      jq
    ];
    runtimeEnv = {
      VOXTYPE_REMOTE_ENDPOINT = "http://${osConfig.tailscaleAddresses.lindbladian.ipv4}:18080";
      VOXTYPE_LOCAL_CLI = getExe' (pkgs.whisper-cpp.override { vulkanSupport = true; }) "whisper-cli";
    };
    text = fileContents ./voxtype-fallback.sh;
  };
in
{
  programs.voxtype.settings.whisper = {
    mode = "cli";
    whisper_cli_path = getExe fallback;
    language = mkForce "auto";
  };
}
