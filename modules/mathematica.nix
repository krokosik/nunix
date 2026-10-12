{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib.lists) singleton;
  inherit (config.home-manager.users.${config.username}.home) sessionVariables;
  version = "15.0.1";
  mathematica = pkgs.unstable.mathematica;
in
{
  nixpkgs.overlays = [
    (_self: super: {
      mathematica = super.mathematica.override {
        source = pkgs.requireFile {
          name = "Wolfram_${version}.sh";
          sha256 = "sha256:0nq3mb0s797xdf4yi8fca3yybw1p1cxp9pqh9zjfzg627h60588l";
          message = ''
            Your override for Mathematica includes a different src for the installer,
            and it is missing. To add the installer to store, run:
            nix-store --query --hash \
            $(nix store add-path Wolfram_${version}.sh --name 'Wolfram_${version}.sh')
          '';
          hashMode = "recursive";
        };
      };
    })
  ];

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
