{ pkgs, lib, ... }:
let
  inherit (lib.lists) singleton;
  inherit (lib.meta) getExe;
  codebase-memory = pkgs.unstable.codebase-memory-mcp;
in
{
  home.packages = singleton codebase-memory;

  programs.mcp = {
    enable = true;
    servers = {
      codebase-memory = {
        command = getExe codebase-memory;
      };
    };
  };
}
