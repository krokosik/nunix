{
  pkgs,
  config,
  inputs,
  lib,
  ...
}:
let
  inherit (lib.lists) singleton;
  inherit (lib.meta) getExe getExe';
  inherit (lib.strings) makeBinPath;
  rea = config.programs.rea.package;
  reaSkill = "${rea}/lib/node_modules/rea-agents/skills/reverse-engineer-anything";
  codexConfigDir = config.home.sessionVariables.CODEX_HOME;
in
{
  imports = singleton inputs.rea-flake.homeManagerModules.default;

  programs.rea = {
    enable = true;
    # Provide child-process ownership checks and packet analysis, including under MCP.
    package = pkgs.symlinkJoin {
      name = "rea-with-tools";
      paths = singleton inputs.rea-flake.packages.${pkgs.stdenv.hostPlatform.system}.rea;
      nativeBuildInputs = singleton pkgs.makeWrapper;
      postBuild = /* bash */ ''
        for program in rea rea-agents; do
          wrapProgram "$out/bin/$program" \
            --set-default REA_TSHARK_PRLIMIT_COMMAND ${getExe' pkgs.util-linux "prlimit"} \
            --prefix PATH : ${
              makeBinPath (
                with pkgs;
                [
                  procps
                  tshark
                ]
              )
            }
        done
      '';
      meta.mainProgram = "rea";
    };
  };

  programs.mcp.servers.rea = {
    command = getExe rea;
    args = singleton "--mcp";
    enabled = false;
  };

  home.file."${codexConfigDir}/skills/reverse-engineer-anything".source = reaSkill;
  xdg.configFile."opencode/skills/reverse-engineer-anything".source = reaSkill;
}
