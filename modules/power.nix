{
  lib,
  pkgs,
  ...
}:
let
  inherit (lib.lists) singleton;
  inherit (lib.meta) getExe;
  tlpExe = getExe pkgs.tlp;
in
{
  # POWER MANAGEMENT
  powerManagement.powertop.enable = true;
  services.tlp.enable = true;

  systemd.services.setBatteryChargeLimit = {
    description = "Set battery charge limit to 75% when started and 96% when stopped";
    enable = false;
    wantedBy = singleton "multi-user.target";

    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = "${tlpExe} setcharge 75 80";
      ExecStop = "${tlpExe} setcharge 96 100";
    };
  };
}
