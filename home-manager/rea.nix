{
  pkgs,
  config,
  inputs,
  lib,
  ...
}:
let
  rea = config.programs.rea.package;
  reaSkill = "${rea}/lib/node_modules/rea-agents/skills/reverse-engineer-anything";
  codexConfigDir = config.home.sessionVariables.CODEX_HOME;
in
{
  imports = lib.lists.singleton inputs.rea-flake.homeManagerModules.default;

  programs.rea = {
    enable = true;
    # REA needs procps for child-process ownership checks, including under MCP.
    package = pkgs.symlinkJoin {
      name = "rea-with-procps";
      paths = lib.lists.singleton inputs.rea-flake.packages.${pkgs.stdenv.hostPlatform.system}.rea;
      nativeBuildInputs = lib.lists.singleton pkgs.makeWrapper;
      postBuild = /* bash */ ''
        for program in rea rea-agents; do
          wrapProgram "$out/bin/$program" \
            --prefix PATH : ${lib.makeBinPath (lib.lists.singleton pkgs.procps)}
        done
      '';
      meta.mainProgram = "rea";
    };
  };

  programs.mcp.servers.rea = {
    command = lib.getExe rea;
    args = lib.lists.singleton "mcp";
  };

  home.file."${codexConfigDir}/skills/reverse-engineer-anything".source = reaSkill;
  xdg.configFile."opencode/skills/reverse-engineer-anything".source = reaSkill;
}
