{
  lib,
  osConfig,
  pkgs,
  ...
}:
let
  inherit (lib.meta) getExe getExe';
  fallback = pkgs.writeShellApplication {
    name = "voxtype-fallback";
    runtimeInputs = [
      pkgs.curl
      pkgs.jq
    ];
    runtimeEnv = {
      VOXTYPE_REMOTE_ENDPOINT = "http://${osConfig.tailscaleAddresses.lindbladian.ipv4}:18080";
      VOXTYPE_LOCAL_CLI = getExe' (pkgs.whisper-cpp.override { vulkanSupport = true; }) "whisper-cli";
    };
    text = lib.strings.fileContents ./voxtype-fallback.sh;
  };
in
{
  programs.voxtype.settings.whisper = {
    mode = "cli";
    whisper_cli_path = getExe fallback;
    language = lib.mkForce "auto";
  };
}
