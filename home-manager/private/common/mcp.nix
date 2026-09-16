{ pkgs, lib, ... }:
let
  codebase-memory = pkgs.unstable.codebase-memory-mcp;
in
{
  home.packages = [ codebase-memory ];

  programs.mcp = {
    enable = true;
    servers = {
      codebase-memory = {
        command = lib.getExe codebase-memory;
      };
    };
  };
}
