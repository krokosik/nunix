{ pkgs, ... }:
{
  imports = [ ../nix-ld.nix ];

  environment.systemPackages = with pkgs; [
    uv
    ruff
    poetry
    nodejs
  ];
}
