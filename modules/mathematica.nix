{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib.lists) singleton;
  inherit (config.home-manager.users.${config.username}.home) sessionVariables;
  mathematica = pkgs.unstable.mathematica.override {
    source = pkgs.requireFile {
      name = "Wolfram_${pkgs.unstable.mathematica.version}.sh";
      sha256 = "sha256:0nq3mb0s797xdf4yi8fca3yybw1p1cxp9pqh9zjfzg627h60588l";
      message = /* bash */ ''
        Add the Mathematica installer to the Nix store:
        nix store add --mode nar --name Wolfram_${pkgs.unstable.mathematica.version}.sh ~/downloads/Wolfram_${pkgs.unstable.mathematica.version}.sh
      '';
      hashMode = "recursive";
    };
  };
in
{
  # Keep the installer reachable from system generations after the build finishes.
  system.extraDependencies = singleton mathematica.src;

  home-manager.users.${config.username} = {
    home.packages = singleton mathematica;

    xdg.dataFile."applications/com.wolfram.Wolfram.15.0.desktop".source =
      pkgs.runCommand "wolfram-desktop" { }
        /* bash */ ''
          cp ${mathematica}/share/applications/com.wolfram.Wolfram.15.0.desktop "$out"
          substituteInPlace "$out" --replace-fail $'\nExec=' \
            $'\nExec=${lib.getExe' pkgs.coreutils "env"} WOLFRAM_USERBASE=${sessionVariables.WOLFRAM_USERBASE} WOLFRAM_LOCALBASE=${sessionVariables.WOLFRAM_LOCALBASE} '
        '';

    programs.mcp.servers.Wolfram = {
      enabled = false;
      command = "${mathematica}/libexec/Mathematica/Executables/wolfram";
      args = [
        "-run"
        "PacletSymbol[\"Wolfram/AgentTools\",\"Wolfram`AgentTools`StartMCPServer\"][]"
        "-noinit"
        "-noprompt"
      ];
      env = {
        inherit (sessionVariables) WOLFRAM_USERBASE WOLFRAM_LOCALBASE;
        MCP_SERVER_NAME = "WolframLanguage";
      };
    };
  };
}
