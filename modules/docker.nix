# Docker
{ config, pkgs, ... }:
{
  virtualisation.docker = {
    enable = true;
  };
  users.users.${config.username}.extraGroups = [ "docker" ];
  environment.systemPackages = with pkgs; [
    docker-compose
  ];
}