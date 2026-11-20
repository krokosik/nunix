{
  config,
  lib,
  ...
}:
let
  inherit (lib.meta) getExe;
in
{
  # Intel GPU counters need perf access; keep it limited to the primary user.
  security.wrappers.btop = {
    source = getExe config.home-manager.users.${config.nunix.self.user}.programs.btop.package;
    owner = "root";
    group = config.users.users.${config.nunix.self.user}.group;
    permissions = "u=rx,g=rx,o=";
    capabilities = "cap_perfmon+ep";
  };
}
