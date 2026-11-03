{
  config,
  lib,
  ...
}:
let
  inherit (lib.modules) mkIf;
in
{
  # FIRMWARE UPDATES - FWUPD
  services.fwupd.enable = mkIf (!config.isVirtual) true;

  # Allow fwupd-refresh to restart if failed (after resume)
  systemd.services.fwupd-refresh = {
    serviceConfig = mkIf (!config.isVirtual) {
      Restart = "on-failure";
      RestartSec = "20";
    };
    unitConfig = mkIf (!config.isVirtual) {
      StartLimitIntervalSec = 100;
      StartLimitBurst = 5;
    };
  };
}
