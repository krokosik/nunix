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
    serviceConfig = {
      Restart = mkIf (!config.isVirtual) "on-failure";
      RestartSec = mkIf (!config.isVirtual) "20";
    };
    unitConfig = {
      StartLimitIntervalSec = mkIf (!config.isVirtual) 100;
      StartLimitBurst = mkIf (!config.isVirtual) 5;
    };
  };
}
