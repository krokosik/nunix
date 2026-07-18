{
  pkgs,
  config,
  ...
}:
{
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
    };
  };
}