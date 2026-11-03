{
  config,
  lib,
  ...
}:
let
  inherit (lib.modules) mkIf;
in
{
  # SMARTMON
  services.smartd = {
    enable = mkIf (!config.isVirtual) true;
    defaults.monitored = mkIf (
      !config.isVirtual
    ) "--all --offlineauto=on --smartctl=on --scan=(S/../.././01|L/../../6/02) --mail=root";
  };
}
