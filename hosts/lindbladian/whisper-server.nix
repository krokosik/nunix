{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib.lists) singleton;
  inherit (lib.meta) getExe';
  modelDefinitions = import "${inputs.voxtype}/nix/models.nix";
  model = pkgs.fetchurl {
    inherit (modelDefinitions.large-v3-turbo) url hash;
  };
  whisper = pkgs.whisper-cpp.override { vulkanSupport = true; };
in
{
  # Bind only to Lindbladian's Tailscale address, never LAN or public interfaces.
  systemd.services.whisper-server = {
    description = "GPU transcription for Surface over Tailscale";
    wantedBy = singleton "multi-user.target";
    wants = singleton "tailscaled.service";
    after = singleton "tailscaled.service";
    serviceConfig = {
      ExecStart = "${getExe' whisper "whisper-server"} --model ${model} --host ${config.tailscaleAddresses.lindbladian.ipv4} --port 18080 --language auto";
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
      IPAddressAllow = "${config.tailscaleAddresses.isis.ipv4}/32";
      RestrictAddressFamilies = [
        "AF_UNIX"
        "AF_INET"
        "AF_INET6"
      ];
      UMask = "0077";
    };
  };
}
