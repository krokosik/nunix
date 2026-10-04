{ pkgs, ... }:
{
  imports = [ ../nix-ld.nix ];

  environment.systemPackages = with pkgs; [
    uv
    ruff
    nodejs
    corepack
    rustup
    stdenv.cc
  ];
}
