{
  pkgs,
  config,
  inputs,
  lib,
  ...
}:
let
  rtk = pkgs.unstable.rtk;
  skillsPath = "${../../../ai/skills}";
  codexConfigDir = config.home.sessionVariables.CODEX_HOME;
  codexConfigPath = "${codexConfigDir}/config.toml";
  codexConfigTarget = lib.strings.removePrefix config.home.homeDirectory codexConfigPath;
  codexConfigSource = config.home.file.${codexConfigTarget}.source;
  codexConfigStateTarget = lib.strings.removePrefix config.home.homeDirectory "${config.xdg.stateHome}/nunix/codex-config.toml";
in
{
  home.packages = [ rtk ];

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
    package = pkgs.unstable.codex;
    skills = skillsPath;
    enableMcpIntegration = config.programs.mcp.enable;
  };

  programs.opencode = {
    enable = true;
    package = inputs.opencode-flake.packages.${pkgs.stdenv.hostPlatform.system}.opencode;
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
      enabled_providers = [
        "opencode-go"
        "openai"
      ];
      provider = {
        "opencode-go".options.apiKey = "{file:${config.sops.secrets.opencode_go_api_key.path}}";
        openai.options.apiKey = "{file:${config.sops.secrets.openai_api_key.path}}";
      };
    };
  };
}
