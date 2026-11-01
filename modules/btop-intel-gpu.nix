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
    source = getExe config.home-manager.users.${config.username}.programs.btop.package;
    owner = "root";
    group = config.users.users.${config.username}.group;
    permissions = "u=rx,g=rx,o=";
    capabilities = "cap_perfmon+ep";
  };
}
