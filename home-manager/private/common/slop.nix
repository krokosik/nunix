{
  pkgs,
  config,
  inputs,
  lib,
  ...
}:
let
  rtk = pkgs.unstable.rtk;
  rea = config.programs.rea.package;
  reaSkill = "${rea}/lib/node_modules/rea-agents/skills/reverse-engineer-anything";
  skillsPath = "${../../../ai/skills}";
  codexConfigDir = config.home.sessionVariables.CODEX_HOME;
  codexConfigPath = "${codexConfigDir}/config.toml";
  codexConfigTarget = lib.strings.removePrefix config.home.homeDirectory codexConfigPath;
  codexConfigSource = config.home.file.${codexConfigTarget}.source;
  codexConfigStateTarget = lib.strings.removePrefix config.home.homeDirectory "${config.xdg.stateHome}/nunix/codex-config.toml";
in
{
  home.packages = [ rtk ];
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

  # Codex records project trust in config.toml, so install a writable copy.
  home.file.${codexConfigTarget}.enable = lib.mkForce false;
  home.file.${codexConfigStateTarget} = {
    source = codexConfigSource;
    onChange = /* bash */ ''
      run ${lib.getExe' pkgs.coreutils "mkdir"} --parents ${lib.escapeShellArg codexConfigDir}
      run ${lib.getExe' pkgs.coreutils "install"} --mode=0600 ${lib.escapeShellArg codexConfigSource} ${lib.escapeShellArg codexConfigPath}
    '';
  };

  home.activation.rtkInit = lib.hm.dag.entryAfter [ "writeBoundary" ] /* bash */ ''
    ${lib.getExe rtk} init --global --opencode
    CODEX_HOME=${lib.escapeShellArg codexConfigDir} ${lib.getExe rtk} init --global --codex
  '';

  sops.secrets = {
    opencode_go_api_key.sopsFile = "${inputs.my-secrets}/common/home.yaml";
    openai_api_key.sopsFile = "${inputs.my-secrets}/common/home.yaml";
  };

  programs.codex = {
    enable = true;
    package = inputs.codex-cli-nix.packages.${pkgs.stdenv.hostPlatform.system}.default;
    skills = skillsPath;
    enableMcpIntegration = config.programs.mcp.enable;
  };

  programs.opencode = {
    enable = true;
    package = inputs.opencode-flake.packages.${pkgs.stdenv.hostPlatform.system}.opencode;
    # (inputs.opencode-flake.packages.${pkgs.stdenv.hostPlatform.system}.opencode2-avx).overrideAttrs
    #   (old: {
    #     postInstall = (old.postInstall or "") + ''
    #       ln -s opencode2 $out/bin/opencode
    #     '';
    #     meta = old.meta // {
    #       mainProgram = "opencode";
    #     };
    #   });
    extraPackages = with pkgs; [
      uv
      nixd
      nh
      nixpkgs-fmt
      ruff
    ];
    skills = skillsPath;
    enableMcpIntegration = config.programs.mcp.enable;
    settings = {
      autoupdate = false;
      small_model = "openai/gpt-6-luna";
      enabled_providers = [
        # "opencode-go"
        "openai"
        "macierz"
      ];
      provider = {
        "opencode-go".options.apiKey = "{file:${config.sops.secrets.opencode_go_api_key.path}}";
        openai.options.apiKey = "{file:${config.sops.secrets.openai_api_key.path}}";
        macierz = {
          npm = "@ai-sdk/openai-compatible";
          name = "Macierz";
          options = {
            baseURL = "http://macierz.qot.internal:11789/v1";
            apiKey = "123";
          };
          models = {
            "qwen3.8-flash-next-coder-iq1_m".name = "qwen3.8-flash-coder";
          };
        };
      };
    };
  };
}
