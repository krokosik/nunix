{
  config,
  lib,
  ...
}:
let
  inherit (lib.modules) mkIf;
  inherit (lib.strings) concatStringsSep;
in
{
  # SMARTMON
  services.smartd = {
    enable = mkIf (!config.isVirtual) true;

    # These are smartd.conf directives, not CLI options; the AGENTS.md rule
    # about expanding short CLI options does not apply here.
    defaults.monitored = concatStringsSep " " [
      "-a"
      "-s (S/../.././01|L/../../6/02)"
      "-M daily"
    ];
  };
}
