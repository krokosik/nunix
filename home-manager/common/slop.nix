{
  pkgs,
  config,
  inputs,
  lib,
  ...
}:
let
  rtk = pkgs.unstable.rtk;
in
{
  home.packages = [ rtk ];

  home.activation.rtkInit = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    ${lib.getExe rtk} init -g --opencode
    ${lib.getExe rtk} init -g --codex
  '';

  sops.secrets = {
    opencode_go_api_key.sopsFile = "${inputs.my-secrets}/common/secrets.yaml";
    openai_api_key.sopsFile = "${inputs.my-secrets}/common/secrets.yaml";
  };

  programs.codex = {
    enable = true;
    package = pkgs.unstable.codex;
    skills = "${../../ai/skills}";
    enableMcpIntegration = config.programs.mcp.enable;
  };

  programs.opencode = {
    enable = true;
    package = pkgs.unstable.opencode;
    extraPackages = with pkgs; [
      uv
      nixd
      nh
      nixpkgs-fmt
      ruff
    ];
    skills = "${../../ai/skills}";
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
