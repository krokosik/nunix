{
  pkgs,
  config,
  inputs,
  ...
}:
{
  sops.secrets = {
    opencode_go_api_key.sopsFile = "${inputs.my-secrets}/common/secrets.yaml";
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
      ];
      provider = {
        "opencode-go".options.apiKey = "{file:${config.sops.secrets.opencode_go_api_key.path}}";
      };
    };
  };
}
